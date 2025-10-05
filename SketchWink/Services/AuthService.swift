import Foundation
import Security
import Combine
import SwiftUI

// MARK: - Authentication Models
struct SignInRequest: Codable {
    let email: String
    let password: String
}

struct SignUpRequest: Codable {
    let email: String
    let password: String
    let name: String
}

struct SocialSignInRequest: Codable {
    let provider: String
    let idToken: SocialIdToken
    let requestSignUp: Bool
}

struct SocialIdToken: Codable {
    let token: String
    let nonce: String?
    let accessToken: String?
    let refreshToken: String?
    let expiresAt: Double?
    let user: SocialIdTokenUser?
}

struct SocialIdTokenUser: Codable {
    let name: SocialIdTokenUserName?
    let email: String?
}

struct SocialIdTokenUserName: Codable {
    let firstName: String?
    let lastName: String?
}

struct SignUpResponse: Codable {
    let message: String
    let user: User?
    let requiresVerification: Bool?
    
    // Computed property for backward compatibility
    var success: Bool {
        return user != nil
    }
}

struct VerifyOTPRequest: Codable {
    let email: String
    let code: String
}

struct SessionToken: Codable {
    let id: String
    let token: String
    let expiresAt: String
}

struct VerifyOTPResponse: Codable {
    let message: String
    let success: Bool
    let user: User?
    let session: SessionToken?
}

struct ResendOTPRequest: Codable {
    let email: String
}

struct ResendOTPResponse: Codable {
    let success: Bool
    let message: String
}

struct ForgotPasswordRequest: Codable {
    let email: String
}

struct ForgotPasswordResponse: Codable {
    let message: String
    let success: Bool
}

struct ResetPasswordRequest: Codable {
    let email: String
    let code: String
    let newPassword: String
}

struct ResetPasswordResponse: Codable {
    let message: String
    let success: Bool
}

struct SignInResponse: Codable {
    let user: User
    let session: Session?
    let token: String?
    let redirect: Bool?
}

struct User: Codable {
    let id: String
    let email: String
    let name: String
    let image: String?
    let emailVerified: Bool
    let createdAt: String
    let updatedAt: String
    let role: String?
    let promptEnhancementEnabled: Bool?
    
    // CodingKeys to handle missing fields gracefully
    enum CodingKeys: String, CodingKey {
        case id, email, name, image, emailVerified, createdAt, updatedAt, role, promptEnhancementEnabled
    }
    
    // Regular initializer for creating User instances
    init(id: String, email: String, name: String, image: String? = nil, emailVerified: Bool, createdAt: String, updatedAt: String, role: String? = "user", promptEnhancementEnabled: Bool? = true) {
        self.id = id
        self.email = email
        self.name = name
        self.image = image
        self.emailVerified = emailVerified
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.role = role
        self.promptEnhancementEnabled = promptEnhancementEnabled
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        name = try container.decode(String.self, forKey: .name)
        image = try container.decodeIfPresent(String.self, forKey: .image)
        emailVerified = try container.decode(Bool.self, forKey: .emailVerified)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? "user"
        promptEnhancementEnabled = try container.decodeIfPresent(Bool.self, forKey: .promptEnhancementEnabled) ?? true
    }
}

struct Session: Codable {
    let id: String
    let token: String
    let expiresAt: String
}

// MARK: - Authentication Errors
enum AuthError: LocalizedError {
    case invalidCredentials
    case networkError(String)
    case invalidResponse
    case tokenStorageError
    case profileStorageError
    case noToken
    case decodingError
    case serverUnavailable
    case networkTimeout
    case userNotFound
    case rateLimited(retryAfter: Int?)
    case invalidOrExpiredCode
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password. Please check your credentials and try again."
        case .networkError(let message):
            return message
        case .invalidResponse:
            return "Invalid response from server. Please try again."
        case .tokenStorageError:
            return "Failed to store authentication token securely."
        case .profileStorageError:
            return "Failed to store profile selection. Please try again."
        case .noToken:
            return "No authentication token found. Please sign in again."
        case .decodingError:
            return "Failed to process server response. Please try again."
        case .serverUnavailable:
            return "Server is temporarily unavailable. Your content will be available when connection is restored."
        case .networkTimeout:
            return "Connection timed out. Please check your internet connection and try again."
        case .userNotFound:
            return "No account found with this email address."
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                let minutes = seconds / 60
                return "Too many requests. Please try again in \(minutes) minute\(minutes == 1 ? "" : "s")."
            }
            return "Too many requests. Please try again later."
        case .invalidOrExpiredCode:
            return "Invalid or expired reset code. Please request a new one."
        }
    }

    var userFriendlyMessage: String {
        return errorDescription ?? "An error occurred. Please try again."
    }
}

// MARK: - Network Status
enum NetworkStatus {
    case connected
    case serverUnavailable
    case networkError
    case timeout
}

// MARK: - Keychain Manager
class KeychainManager {
    static let shared = KeychainManager()
    private init() {}
    
    private let service = AppConfig.Security.keychainService
    private let tokenKey = AppConfig.Security.tokenKey
    private let profileKey = AppConfig.Security.profileKey
    
    func storeToken(_ token: String) throws {
        let data = token.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: data
        ]
        
        // Delete existing token
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw AuthError.tokenStorageError
        }
    }
    
    func retrieveToken() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Profile Storage
    func storeSelectedProfile(_ profileId: String) throws {
        let data = profileId.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profileKey,
            kSecValueData as String: data
        ]
        
        // Delete existing profile
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw AuthError.profileStorageError
        }
    }
    
    func retrieveSelectedProfile() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profileKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let profileId = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return profileId
    }
    
    func deleteSelectedProfile() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profileKey
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Authentication Service
class AuthService: ObservableObject {
    static let shared = AuthService()
    private init() {}
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var networkStatus: NetworkStatus = .connected
    @Published var lastAuthCheckError: AuthError?
    
    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    // MARK: - Sign Up
    func signUp(email: String, password: String, name: String) async throws -> SignUpResponse {
        let request = SignUpRequest(email: email, password: password, name: name)
        
        guard let url = URL(string: AppConfig.apiURL(for: AppConfig.API.Endpoints.signUp)) else {
            throw AuthError.invalidResponse
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = AppConfig.API.timeout
        
        do {
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            throw AuthError.decodingError
        }
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                if let apiError = try? decoder.decode(APIError.self, from: data) {
                    throw AuthError.networkError(apiError.userMessage)
                } else {
                    throw AuthError.networkError("Server error: \(httpResponse.statusCode)")
                }
            }
            
            return try decoder.decode(SignUpResponse.self, from: data)
            
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Verify OTP
    func verifyOTP(email: String, code: String) async throws -> VerifyOTPResponse {
        let request = VerifyOTPRequest(email: email, code: code)
        
        guard let url = URL(string: AppConfig.apiURL(for: AppConfig.API.Endpoints.verifyOTP)) else {
            throw AuthError.invalidResponse
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = AppConfig.API.timeout
        
        do {
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            throw AuthError.decodingError
        }
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                if let apiError = try? decoder.decode(APIError.self, from: data) {
                    throw AuthError.networkError(apiError.userMessage)
                } else {
                    throw AuthError.networkError("Server error: \(httpResponse.statusCode)")
                }
            }
            
            return try decoder.decode(VerifyOTPResponse.self, from: data)
            
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Resend OTP
    func resendOTP(email: String) async throws -> ResendOTPResponse {
        let request = ResendOTPRequest(email: email)
        
        guard let url = URL(string: AppConfig.apiURL(for: AppConfig.API.Endpoints.resendOTP)) else {
            throw AuthError.invalidResponse
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = AppConfig.API.timeout
        
        do {
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            throw AuthError.decodingError
        }
        
        do {
            let (data, response) = try await session.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                if let apiError = try? decoder.decode(APIError.self, from: data) {
                    throw AuthError.networkError(apiError.userMessage)
                } else {
                    throw AuthError.networkError("Server error: \(httpResponse.statusCode)")
                }
            }
            
            return try decoder.decode(ResendOTPResponse.self, from: data)
            
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkError(error.localizedDescription)
        }
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async throws -> User {
        let request = SignInRequest(email: email, password: password)
        
        guard let url = URL(string: AppConfig.apiURL(for: AppConfig.API.Endpoints.signIn)) else {
            throw AuthError.invalidResponse
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = AppConfig.API.timeout
        
        do {
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            throw AuthError.decodingError
        }
        
        do {
            // Debug logging
            if AppConfig.Debug.enableLogging {
                print("🌐 Making request to: \(urlRequest.url?.absoluteString ?? "unknown")")
                print("📤 Request body: \(String(data: urlRequest.httpBody ?? Data(), encoding: .utf8) ?? "empty")")
            }
            
            let (data, response) = try await session.data(for: urlRequest)
            
            // Debug logging
            if AppConfig.Debug.enableLogging {
                print("📥 Response data: \(String(data: data, encoding: .utf8) ?? "no data")")
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }
            
            if AppConfig.Debug.enableLogging {
                print("📊 HTTP Status: \(httpResponse.statusCode)")
            }
            
            if httpResponse.statusCode == 401 {
                throw AuthError.invalidCredentials
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                // Try to decode error message
                if let apiError = try? decoder.decode(APIError.self, from: data) {
                    throw AuthError.networkError(apiError.userMessage)
                } else {
                    throw AuthError.networkError("Server error: \(httpResponse.statusCode)")
                }
            }
            
            let signInResponse = try decoder.decode(SignInResponse.self, from: data)

            guard let token = signInResponse.session?.token ?? signInResponse.token else {
                throw AuthError.invalidResponse
            }

            try KeychainManager.shared.storeToken(token)

            await MainActor.run {
                self.currentUser = signInResponse.user
                self.isAuthenticated = true
            }

            return signInResponse.user
            
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkError(error.localizedDescription)
        }
    }

    // MARK: - Sign In with Apple
    func signInWithApple(
        identityToken: String,
        hashedNonce: String?,
        givenName: String?,
        familyName: String?,
        email: String?,
        requestSignUp: Bool = true
    ) async throws -> User {
        let request = SocialSignInRequest(
            provider: "apple",
            idToken: SocialIdToken(
                token: identityToken,
                nonce: hashedNonce,
                accessToken: nil,
                refreshToken: nil,
                expiresAt: nil,
                user: makeSocialUser(givenName: givenName, familyName: familyName, email: email)
            ),
            requestSignUp: requestSignUp
        )

        guard let url = URL(string: AppConfig.apiURL(for: AppConfig.API.Endpoints.signInApple)) else {
            throw AuthError.invalidResponse
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = AppConfig.API.timeout

        do {
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            throw AuthError.decodingError
        }

        do {
            if AppConfig.Debug.enableLogging {
                print("🌐 Apple sign-in request to: \(urlRequest.url?.absoluteString ?? "unknown")")
            }

            let (data, response) = try await session.data(for: urlRequest)

            if AppConfig.Debug.enableLogging {
                print("📥 Apple sign-in response: \(String(data: data, encoding: .utf8) ?? "no data")")
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                throw AuthError.invalidResponse
            }

            if httpResponse.statusCode == 401 {
                throw AuthError.invalidCredentials
            }

            if !(200...299).contains(httpResponse.statusCode) {
                if let apiError = try? decoder.decode(APIError.self, from: data) {
                    throw AuthError.networkError(apiError.userMessage)
                } else {
                    throw AuthError.networkError("Server error: \(httpResponse.statusCode)")
                }
            }

            let signInResponse = try decoder.decode(SignInResponse.self, from: data)

            guard let token = signInResponse.session?.token ?? signInResponse.token else {
                throw AuthError.invalidResponse
            }

            try KeychainManager.shared.storeToken(token)

            await MainActor.run {
                self.currentUser = signInResponse.user
                self.isAuthenticated = true
            }

            return signInResponse.user

        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.networkError(error.localizedDescription)
        }
    }

    private func makeSocialUser(givenName: String?, familyName: String?, email: String?) -> SocialIdTokenUser? {
        let hasFirstName = givenName?.isEmpty == false
        let hasLastName = familyName?.isEmpty == false
        let hasEmail = email?.isEmpty == false

        if !hasFirstName && !hasLastName && !hasEmail {
            return nil
        }

        let name: SocialIdTokenUserName? = (hasFirstName || hasLastName)
            ? SocialIdTokenUserName(firstName: hasFirstName ? givenName : nil,
                                    lastName: hasLastName ? familyName : nil)
            : nil

        return SocialIdTokenUser(name: name, email: hasEmail ? email : nil)
    }
    
    // MARK: - Sign Out
    func signOut() {
        // Clear auth state FIRST (immediate, no delay for local operations)
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.5)) {
                self.currentUser = nil
                self.isAuthenticated = false
            }
        }

        // Then clear keychain and profile state (can happen in background)
        KeychainManager.shared.deleteToken()
        KeychainManager.shared.deleteSelectedProfile()
        ProfileService.shared.clearSelectedProfile()
        TokenBalanceManager.shared.clearState()
    }
    
    // MARK: - Check Authentication Status
    func checkAuthenticationStatus() async {
        guard let token = try? KeychainManager.shared.retrieveToken() else {
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
                self.networkStatus = .connected
                self.lastAuthCheckError = nil
            }
            return
        }
        
        // Validate token with backend by making a test API call
        do {
            let endpoint = AppConfig.apiURL(for: AppConfig.API.Endpoints.tokenBalance)
            guard let url = URL(string: endpoint) else {
                await handleNetworkIssue(.networkError)
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 8.0 // Shorter timeout for faster detection
            
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await handleNetworkIssue(.networkError)
                return
            }
            
            // ONLY logout for actual authentication failures (401/403)
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                // Token is invalid - user was deleted, token expired, or unauthorized
                await handleInvalidAuth()
                return
            }
            
            if 200...299 ~= httpResponse.statusCode {
                // Token is valid and server is working
                await MainActor.run {
                    self.isAuthenticated = true
                    self.networkStatus = .connected
                    self.lastAuthCheckError = nil
                }
            } else if httpResponse.statusCode >= 500 {
                // Server error - keep user logged in
                await handleNetworkIssue(.serverUnavailable)
            } else {
                // Other client errors (4xx) - keep user logged in but note the issue
                await MainActor.run {
                    self.isAuthenticated = true
                    self.networkStatus = .connected
                    self.lastAuthCheckError = .networkError("Server returned error \(httpResponse.statusCode)")
                }
            }
            
        } catch {
            // Analyze the specific error to provide better user experience
            if let urlError = error as? URLError {
                switch urlError.code {
                case .timedOut:
                    await handleNetworkIssue(.timeout)
                case .notConnectedToInternet, .networkConnectionLost:
                    await handleNetworkIssue(.networkError)
                case .cannotConnectToHost, .cannotFindHost:
                    await handleNetworkIssue(.serverUnavailable)
                default:
                    await handleNetworkIssue(.networkError)
                }
            } else {
                // Unknown error - treat as network issue
                await handleNetworkIssue(.networkError)
            }
        }
    }
    
    // MARK: - Handle Invalid Authentication
    private func handleInvalidAuth() async {
        print("🚨 AuthService: Invalid token detected - logging out user")
        
        // Token is invalid - clear everything and force re-login
        KeychainManager.shared.deleteToken()
        KeychainManager.shared.deleteSelectedProfile()
        ProfileService.shared.clearSelectedProfile()
        
        await MainActor.run {
            self.isAuthenticated = false
            self.currentUser = nil
            self.networkStatus = .connected
            self.lastAuthCheckError = nil
        }
    }
    
    // MARK: - Handle Network Issues
    private func handleNetworkIssue(_ status: NetworkStatus) async {
        let errorMessage: AuthError
        
        switch status {
        case .serverUnavailable:
            errorMessage = .serverUnavailable
            print("🌐 AuthService: Server unavailable - keeping user logged in")
        case .timeout:
            errorMessage = .networkTimeout
            print("⏱️ AuthService: Network timeout - keeping user logged in")
        case .networkError:
            errorMessage = .networkError("Network connection issue")
            print("📡 AuthService: Network error - keeping user logged in")
        case .connected:
            errorMessage = .networkError("Unknown network issue")
        }
        
        // Keep user logged in but update network status for UI
        await MainActor.run {
            self.isAuthenticated = true
            self.networkStatus = status
            self.lastAuthCheckError = errorMessage
        }
    }
    
    // MARK: - Get Current Token
    func getCurrentToken() throws -> String {
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw AuthError.noToken
        }
        return token
    }
    
    // MARK: - Handle Unauthorized Response
    /// Call this method from any service when receiving a 401 Unauthorized response
    /// This will automatically log out the user and clear all stored data
    static func handleUnauthorizedResponse() {
        Task {
            await AuthService.shared.handleInvalidAuth()
        }
    }
    
    // MARK: - Network Status Management
    /// Retry authentication check manually
    func retryAuthenticationCheck() async {
        await checkAuthenticationStatus()
    }
    
    /// Clear network status (call when user manually dismisses network errors)
    func clearNetworkStatus() {
        DispatchQueue.main.async {
            self.networkStatus = .connected
            self.lastAuthCheckError = nil
        }
    }
    
    /// Update network status from external services (e.g., ProfileService)
    func updateNetworkStatus(_ status: NetworkStatus) async {
        await handleNetworkIssue(status)
    }
    
    /// Check if current network status allows normal app operation
    var isNetworkAvailable: Bool {
        return networkStatus == .connected && lastAuthCheckError == nil
    }
    // MARK: - Password Reset

    /// Request password reset code
    func requestPasswordReset(email: String) async throws {
        let endpoint = "\(AppConfig.API.baseURL)/auth/forgot-password"

        guard let url = URL(string: endpoint) else {
            throw AuthError.invalidResponse
        }

        let request = ForgotPasswordRequest(email: email)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        #if DEBUG
        print("📧 AuthService: Password reset request - Status: \(httpResponse.statusCode)")
        #endif

        // Handle different status codes
        switch httpResponse.statusCode {
        case 200:
            // Success
            return
        case 404:
            throw AuthError.userNotFound
        case 429:
            // Parse retry-after from response if available
            if let errorResponse = try? JSONDecoder().decode(APIError.self, from: data),
               let retryAfter = errorResponse.retryAfter {
                throw AuthError.rateLimited(retryAfter: retryAfter)
            }
            throw AuthError.rateLimited(retryAfter: 900) // 15 minutes default
        default:
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw AuthError.networkError(apiError.error)
            }
            throw AuthError.networkError("Failed to send reset code")
        }
    }

    /// Reset password with code
    func resetPassword(email: String, code: String, newPassword: String) async throws {
        let endpoint = "\(AppConfig.API.baseURL)/auth/reset-password"

        guard let url = URL(string: endpoint) else {
            throw AuthError.invalidResponse
        }

        let request = ResetPasswordRequest(email: email, code: code, newPassword: newPassword)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        #if DEBUG
        print("🔐 AuthService: Password reset - Status: \(httpResponse.statusCode)")
        #endif

        // Handle different status codes
        switch httpResponse.statusCode {
        case 200:
            // Success
            return
        case 400:
            throw AuthError.invalidOrExpiredCode
        case 404:
            throw AuthError.userNotFound
        default:
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw AuthError.networkError(apiError.error)
            }
            throw AuthError.networkError("Failed to reset password")
        }
    }
}

// MARK: - Auth Service Extensions
extension AuthService {
    
    /// Validates email format
    static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    /// Validates password strength
    static func isValidPassword(_ password: String) -> Bool {
        return password.count >= 6 // Minimum 6 characters
    }
    
    /// Validates sign in form
    static func canSignIn(email: String, password: String) -> Bool {
        return isValidEmail(email) && isValidPassword(password)
    }
}
