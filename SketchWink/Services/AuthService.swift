import Foundation
import Security
import Combine

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

struct SignInResponse: Codable {
    let user: User
    let session: Session
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
        }
    }
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
            
            // Store token securely
            try KeychainManager.shared.storeToken(signInResponse.session.token)
            
            // Update published properties on main thread
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
    
    // MARK: - Sign Out
    func signOut() {
        KeychainManager.shared.deleteToken()
        KeychainManager.shared.deleteSelectedProfile()
        
        // Clear profile service state
        ProfileService.shared.clearSelectedProfile()
        
        DispatchQueue.main.async {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
    
    // MARK: - Check Authentication Status
    func checkAuthenticationStatus() async {
        guard let token = try? KeychainManager.shared.retrieveToken() else {
            await MainActor.run {
                self.isAuthenticated = false
                self.currentUser = nil
            }
            return
        }
        
        // TODO: Validate token with backend
        // For now, assume token is valid if it exists
        await MainActor.run {
            self.isAuthenticated = true
        }
    }
    
    // MARK: - Get Current Token
    func getCurrentToken() throws -> String {
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw AuthError.noToken
        }
        return token
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