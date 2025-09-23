import Foundation

/// Centralized API request helper that automatically adds required headers
/// including Authorization and X-Profile-ID for family profile system
class APIRequestHelper {
    static let shared = APIRequestHelper()
    private init() {}
    
    /// Creates a URLRequest with standard headers including auth token and profile ID
    /// - Parameters:
    ///   - url: The URL for the request
    ///   - method: HTTP method (GET, POST, etc.)
    ///   - includeProfileHeader: Whether to include X-Profile-ID header (default: true)
    /// - Returns: Configured URLRequest with all required headers
    /// - Throws: AuthError if token retrieval fails
    func createRequest(
        url: URL,
        method: String = "GET",
        includeProfileHeader: Bool = true
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = AppConfig.API.timeout
        
        // Add Authorization header
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw AuthError.noToken
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Add profile header for content requests
        if includeProfileHeader {
            if let profileId = try? KeychainManager.shared.retrieveSelectedProfile() {
                request.setValue(profileId, forHTTPHeaderField: "X-Profile-ID")
                
                #if DEBUG
                print("🔖 API Request with Profile ID: \(profileId)")
                #endif
            } else {
                #if DEBUG
                print("⚠️ API Request without Profile ID - this may limit content access")
                #endif
            }
        }
        
        return request
    }
    
    /// Creates a POST request with JSON body and standard headers
    /// - Parameters:
    ///   - url: The URL for the request
    ///   - body: Encodable object to be sent as JSON
    ///   - includeProfileHeader: Whether to include X-Profile-ID header
    /// - Returns: Configured URLRequest with JSON body and headers
    /// - Throws: AuthError or encoding errors
    func createJSONRequest<T: Encodable>(
        url: URL,
        method: String = "POST",
        body: T,
        includeProfileHeader: Bool = true
    ) throws -> URLRequest {
        var request = try createRequest(url: url, method: method, includeProfileHeader: includeProfileHeader)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(body)
            request.httpBody = jsonData
            
            #if DEBUG
            if let requestString = String(data: jsonData, encoding: .utf8) {
                print("📤 \(method) \(url.path): \(requestString)")
            }
            #endif
        } catch {
            throw AuthError.encodingError
        }
        
        return request
    }
    
    /// Creates a GET request with standard headers
    /// - Parameters:
    ///   - url: The URL for the request
    ///   - includeProfileHeader: Whether to include X-Profile-ID header
    /// - Returns: Configured URLRequest with headers
    /// - Throws: AuthError if token retrieval fails
    func createGETRequest(
        url: URL,
        includeProfileHeader: Bool = true
    ) throws -> URLRequest {
        var request = try createRequest(url: url, method: "GET", includeProfileHeader: includeProfileHeader)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
    
    /// Get current selected profile ID for debugging
    var currentProfileId: String? {
        return try? KeychainManager.shared.retrieveSelectedProfile()
    }
    
    /// Check if a profile is currently selected
    var hasSelectedProfile: Bool {
        return currentProfileId != nil
    }
}

// MARK: - Auth Error Extensions
extension AuthError {
    static let encodingError = AuthError.invalidResponse // Reuse existing error type
}