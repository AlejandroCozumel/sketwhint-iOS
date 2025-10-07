
import Foundation

// MARK: - Subscription Service Models

struct SubscriptionVerificationRequest: Codable {
    let productId: String
    let transactionId: String
    let signedTransactionInfo: String?
    let appAccountToken: String?
}

struct SubscriptionVerificationResponse: Codable {
    let status: String
    let subscription: SubscriptionDetails?
}

struct SubscriptionDetails: Codable {
    let planId: String
    let status: String
    let currentPeriodStart: String
    let currentPeriodEnd: String
}

enum SubscriptionError: Error {
    case verificationFailed(Error)
    case apiError(String)
    case decodingError
}

// MARK: - SubscriptionService

class SubscriptionService {

    static let shared = SubscriptionService()
    private init() {}

    /// Verifies a subscription with the backend after a successful StoreKit transaction.
    /// - Parameters:
    ///   - requestData: The data required for verification, including product and transaction IDs.
    ///   - completion: A closure that returns a `Result` with either a `SubscriptionVerificationResponse` or a `SubscriptionError`.
    func verifySubscription(
        requestData: SubscriptionVerificationRequest
    ) async throws -> SubscriptionVerificationResponse {
        guard let url = URL(string: AppConfig.apiURL(for: "/apple/subscriptions/verify")) else {
            throw SubscriptionError.apiError("Invalid URL")
        }

        let request = try APIRequestHelper.shared.createJSONRequest(
            url: url,
            method: "POST",
            body: requestData,
            includeProfileHeader: true // Auth is required
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SubscriptionError.apiError("Invalid response from server.")
        }

        #if DEBUG
        if let responseString = String(data: data, encoding: .utf8) {
            print("🍏 Subscription Verification Response [\(httpResponse.statusCode)]:\n\(responseString)")
        }
        #endif

        do {
            let decoder = JSONDecoder()
            let verificationResponse = try decoder.decode(SubscriptionVerificationResponse.self, from: data)

            if (200...299).contains(httpResponse.statusCode) {
                return verificationResponse
            } else {
                throw SubscriptionError.apiError("Verification failed with status: \(httpResponse.statusCode)")
            }
        } catch {
            throw SubscriptionError.decodingError
        }
    }
}
