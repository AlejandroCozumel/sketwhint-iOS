
import Foundation
import Combine
import StoreKit

@MainActor
class SubscriptionViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var showingError = false
    @Published var errorMessage = ""

    @Published private(set) var storeKitManager = StoreKitManager()
    private let subscriptionService = SubscriptionService.shared

    func purchase(plan: PlanCard, isYearly: Bool) {
        isLoading = true

        guard let productId = appleProductId(for: plan.id, isYearly: isYearly),
              let product = storeKitManager.products.first(where: { $0.id == productId }) else {
            self.errorMessage = "The selected plan is currently unavailable. Please try again later."
            self.showingError = true
            self.isLoading = false
            return
        }

        Task {
            do {
                let appAccountToken = getAppAccountToken()
                guard let verificationResult = try await storeKitManager.purchase(product, appAccountToken: appAccountToken) else {
                    // User cancelled or purchase is pending
                    self.isLoading = false
                    return
                }

                // Unwrap verification result
                switch verificationResult {
                case .verified(let transaction):
                    // Transaction successful, now verify with backend
                    let jws = verificationResult.jwsRepresentation
                    await self.verifyTransaction(transaction, for: product, appAccountToken: appAccountToken, jws: jws)
                case .unverified:
                    // Handle unverified transaction
                    self.errorMessage = "Your purchase could not be verified. Please contact support."
                    self.showingError = true
                    self.isLoading = false
                @unknown default:
                    self.isLoading = false
                }

            } catch {
                self.isLoading = false
                self.errorMessage = "An error occurred during the purchase. Please try again."
                self.showingError = true
                print("Purchase failed: \(error.localizedDescription)")
            }
        }
    }

    @available(iOS 15.0, *)
    private func verifyTransaction(_ transaction: Transaction, for product: Product, appAccountToken: UUID?, jws: String) async {
        print("Verifying transaction \(transaction.id) with backend...")

        var appAccountTokenString: String? = appAccountToken?.uuidString
        if appAccountTokenString == nil {
            if #available(iOS 16.0, *) {
                appAccountTokenString = transaction.appAccountToken?.uuidString
            }
        }

        let request = SubscriptionVerificationRequest(
            productId: product.id,
            transactionId: String(transaction.id),
            signedTransactionInfo: jws,
            appAccountToken: appAccountTokenString
        )

        do {
            let response = try await subscriptionService.verifySubscription(requestData: request)
            self.isLoading = false

            if response.status == "processed" {
                // SUCCESS!
                print("✅ Subscription successfully verified and activated!")
                self.errorMessage = "Purchase successful!"
                self.showingError = true // Re-using error alert for success message
                await transaction.finish()
                await TokenBalanceManager.shared.refresh()
            } else if response.status == "pending" {
                self.errorMessage = "Your purchase is pending confirmation from Apple. We'll notify you once it's complete."
                self.showingError = true
            }
        } catch {
            self.isLoading = false
            self.errorMessage = "Failed to verify your purchase with our server. Please contact support. Error: \(error.localizedDescription)"
            self.showingError = true
        }
    }

    // Map UI plan IDs to App Store product identifiers
    private func appleProductId(for planId: String, isYearly: Bool) -> String? {
        switch planId {
        case "basic":
            return isYearly ? AppConfig.Subscriptions.AppleProductIDs.basicYearly
                            : AppConfig.Subscriptions.AppleProductIDs.basicMonthly
        case "pro":
            return isYearly ? AppConfig.Subscriptions.AppleProductIDs.proYearly
                            : AppConfig.Subscriptions.AppleProductIDs.proMonthly
        case "max":
            return isYearly ? AppConfig.Subscriptions.AppleProductIDs.maxYearly
                            : AppConfig.Subscriptions.AppleProductIDs.maxMonthly
        case "business":
            return isYearly ? AppConfig.Subscriptions.AppleProductIDs.businessYearly
                            : AppConfig.Subscriptions.AppleProductIDs.businessMonthly
        default:
            return nil
        }
    }

    // Stable appAccountToken per user for StoreKit linkage and backend verification
    private func getAppAccountToken() -> UUID? {
        guard #available(iOS 16.0, *) else { return nil }
        guard let userId = AuthService.shared.currentUser?.id else { return nil }

        // If backend userId is already a UUID, use it directly
        if let uuid = UUID(uuidString: userId) {
            return uuid
        }

        // Otherwise create/persist a stable UUID key for this user id
        let defaultsKey = "appAccountToken.\(userId)"
        if let saved = UserDefaults.standard.string(forKey: defaultsKey),
           let uuid = UUID(uuidString: saved) {
            return uuid
        }

        let newUUID = UUID()
        UserDefaults.standard.set(newUUID.uuidString, forKey: defaultsKey)
        return newUUID
    }
}
