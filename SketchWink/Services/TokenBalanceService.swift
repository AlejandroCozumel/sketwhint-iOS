import Foundation
import Combine

// MARK: - Token Balance Service Errors
enum TokenBalanceError: LocalizedError {
    case noAuthToken
    case httpError(Int)
    case decodingError(String)
    case networkError(Error)
    case specificError(String)
    
    var errorDescription: String? {
        switch self {
        case .noAuthToken:
            return "Authentication required. Please sign in to continue."
        case .httpError(let code):
            return "Server error (\(code)). Please try again later."
        case .decodingError(let details):
            return "Data processing error: \(details)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .specificError(let message):
            return message  // Direct API error message
        }
    }
}

// MARK: - Token Balance Service
/// Service responsible for fetching and managing user token balance and permissions
class TokenBalanceService: ObservableObject {
    
    // MARK: - Properties
    private let baseURL = AppConfig.API.baseURL
    private let session = URLSession.shared
    
    // MARK: - Public Methods
    
    /// Fetch current user's token balance and permissions
    /// - Returns: TokenBalanceResponse with complete balance and permission information
    /// - Throws: TokenBalanceError for various failure scenarios
    func fetchTokenBalance() async throws -> TokenBalanceResponse {
        print("🔍 TokenBalanceService: Fetching user token balance")
        
        // Get authentication token
        guard let authToken = try KeychainManager.shared.retrieveToken() else {
            print("❌ TokenBalanceService: No auth token found")
            throw TokenBalanceError.noAuthToken
        }
        
        // Construct request URL
        let endpoint = "\(baseURL)\(AppConfig.API.Endpoints.tokenBalance)"
        guard let url = URL(string: endpoint) else {
            print("❌ TokenBalanceService: Invalid URL: \(endpoint)")
            throw TokenBalanceError.networkError(URLError(.badURL))
        }
        
        // Configure request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = AppConfig.API.timeout
        
        print("📤 TokenBalanceService: Making GET request to \(endpoint)")
        
        do {
            // Make network request
            let (data, response) = try await session.data(for: request)
            
            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TokenBalanceError.networkError(URLError(.badServerResponse))
            }
            
            print("📥 TokenBalanceService: Received response with status code: \(httpResponse.statusCode)")
            
            // Handle non-success HTTP status codes
            guard 200...299 ~= httpResponse.statusCode else {
                // Handle unauthorized responses by automatically logging out
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    AuthService.handleUnauthorizedResponse()
                }
                
                // Try to decode API error message first, fallback to generic error
                if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                    print("❌ TokenBalanceService: API Error: \(apiError.userMessage)")
                    throw TokenBalanceError.specificError(apiError.userMessage)
                } else {
                    print("❌ TokenBalanceService: HTTP Error: \(httpResponse.statusCode)")
                    throw TokenBalanceError.httpError(httpResponse.statusCode)
                }
            }
            
            // Debug logging available if needed for troubleshooting
            // Uncomment the lines below to debug API response structure:
            // if let jsonString = String(data: data, encoding: .utf8) {
            //     print("🔍 TokenBalanceService: Raw API response:")
            //     print(jsonString)
            // }
            
            // Decode response
            do {
                let tokenBalance = try JSONDecoder().decode(TokenBalanceResponse.self, from: data)
                
                print("✅ TokenBalanceService: Successfully fetched token balance")
                print("🎯 TokenBalanceService: Total tokens: \(tokenBalance.totalTokens)")
                print("💳 TokenBalanceService: Plan: \(tokenBalance.permissions.planName)")
                print("🔑 TokenBalanceService: Account type: \(tokenBalance.permissions.accountType)")
                
                return tokenBalance
                
            } catch {
                print("❌ TokenBalanceService: Failed to decode response: \(error)")
                
                // Provide detailed decoding error information
                let decodingDetails: String
                if let decodingError = error as? DecodingError {
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        decodingDetails = "Missing key '\(key.stringValue)' in \(context.debugDescription)"
                    case .typeMismatch(let type, let context):
                        decodingDetails = "Type mismatch for \(type) in \(context.debugDescription)"
                    case .valueNotFound(let type, let context):
                        decodingDetails = "Value not found for \(type) in \(context.debugDescription)"
                    case .dataCorrupted(let context):
                        decodingDetails = "Data corrupted: \(context.debugDescription)"
                    @unknown default:
                        decodingDetails = "Unknown decoding error: \(error.localizedDescription)"
                    }
                } else {
                    decodingDetails = error.localizedDescription
                }
                
                throw TokenBalanceError.decodingError(decodingDetails)
            }
            
        } catch {
            // Handle network errors
            if error is TokenBalanceError {
                throw error // Re-throw our custom errors
            } else {
                print("❌ TokenBalanceService: Network error: \(error)")
                throw TokenBalanceError.networkError(error)
            }
        }
    }
    
    /// Check if user can perform a generation based on token cost
    /// - Parameter cost: Token cost for the generation (default: 1)
    /// - Returns: Boolean indicating if user has sufficient tokens
    func canAffordGeneration(cost: Int = 1) async throws -> Bool {
        let tokenBalance = try await fetchTokenBalance()
        return tokenBalance.totalTokens >= cost
    }
    
    /// Get user's feature permissions for UI state management
    /// - Returns: UserPermissions object with all feature access information
    func fetchPermissions() async throws -> UserPermissions {
        let tokenBalance = try await fetchTokenBalance()
        return tokenBalance.permissions
    }
}

