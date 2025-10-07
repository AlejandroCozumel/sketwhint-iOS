
import Foundation
import Combine
import StoreKit


// MARK: - StoreKitManager

@MainActor
class StoreKitManager: ObservableObject {

    @Published private(set) var products: [Product] = []
    @Published private(set) var isFetchingProducts = false

    private var transactionListener: Task<Void, Error>? = nil
    private var fetchAttempts = 0
    private let maxFetchAttempts = 2

    private let productIds = [
        AppConfig.Subscriptions.AppleProductIDs.basicMonthly, AppConfig.Subscriptions.AppleProductIDs.basicYearly,
        AppConfig.Subscriptions.AppleProductIDs.proMonthly, AppConfig.Subscriptions.AppleProductIDs.proYearly,
        AppConfig.Subscriptions.AppleProductIDs.maxMonthly, AppConfig.Subscriptions.AppleProductIDs.maxYearly,
        AppConfig.Subscriptions.AppleProductIDs.businessMonthly, AppConfig.Subscriptions.AppleProductIDs.businessYearly
    ]

    init() {
        transactionListener = listenForTransactions()

        Task {
            await fetchProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    /// Fetches products from the App Store.
    func fetchProducts() async {
        guard !isFetchingProducts else { return }
        isFetchingProducts = true

        do {
            #if DEBUG
            print("🛒 Requesting StoreKit products for IDs: \(productIds)")
            print("📦 Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown") | Env: \(AppConfig.environmentName)")
            #endif

            let storeProducts = try await Product.products(for: productIds)
            self.products = storeProducts
            print("🛒 Fetched \(storeProducts.count) products from StoreKit")

            if storeProducts.isEmpty && fetchAttempts < maxFetchAttempts {
                fetchAttempts += 1
                print("🔁 StoreKit returned 0 products. Retrying fetch (\(fetchAttempts)/\(maxFetchAttempts)) in 2s...")
                isFetchingProducts = false
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await fetchProducts()
                return
            }

            if storeProducts.isEmpty {
                print("""
                ⚠️ StoreKit returned 0 products.
                Common causes:
                 • Product IDs not created/approved in App Store Connect
                 • Bundle ID mismatch with App Store Connect
                 • Not signed into App Store on device or StoreKit Testing not configured
                 • Using Sandbox/TestFlight without proper tester account
                 • Product IDs in code do not match App Store Connect (expected: \(productIds))
                """)
            }
        } catch {
            print("Failed to fetch products: \(error)")
        }

        isFetchingProducts = false
    }

    /// Initiates a purchase for a given product, optionally attaching an appAccountToken for backend cross-checks.
    /// Passing appAccountToken ensures StoreKit ties the transaction to a stable user identifier.
    func purchase(_ product: Product, appAccountToken: UUID? = nil) async throws -> VerificationResult<Transaction>? {
        if #available(iOS 16.0, *), let token = appAccountToken {
            let result = try await product.purchase(options: [.appAccountToken(token)])
            switch result {
            case .success(let verification):
                return verification
            case .userCancelled, .pending:
                return nil
            @unknown default:
                return nil
            }
        } else {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                return verification
            case .userCancelled, .pending:
                return nil
            @unknown default:
                return nil
            }
        }
    }

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    let jws = result.jwsRepresentation

                    // Extract appAccountToken if available
                    var appAccountTokenString: String? = nil
                    if #available(iOS 16.0, *) {
                        appAccountTokenString = transaction.appAccountToken?.uuidString
                    }

                    // Always call backend to verify and sync the transaction
                    let request = SubscriptionVerificationRequest(
                        productId: transaction.productID,
                        transactionId: String(transaction.id),
                        signedTransactionInfo: jws,
                        appAccountToken: appAccountTokenString
                    )

                    print("Transaction listener: Verifying transaction \(transaction.id) with backend...")
                    let response = try await SubscriptionService.shared.verifySubscription(requestData: request)

                    if response.status == "processed" {
                        print("✅ Transaction listener: Successfully verified transaction \(transaction.id). Finishing.")
                        await transaction.finish()
                        // Notify the app that user's token balance might have changed
                        await TokenBalanceManager.shared.refresh()
                    } else {
                        print("Transaction listener: Verification for tx \(transaction.id) returned status \(response.status). Not finishing.")
                    }

                } catch {
                    print("Transaction listener error: \(error)")
                }
            }
        }
    }

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreKitError.failedVerification(result as! VerificationResult<Transaction>)
        case .verified(let safe):
            return safe
        }
    }
}

fileprivate enum StoreKitError: Error {
    case failedVerification(VerificationResult<Transaction>)
    case unknown
}
