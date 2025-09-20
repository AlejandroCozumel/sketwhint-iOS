import Foundation

// MARK: - Common API Models

/// Standard API error response structure
struct APIError: Codable {
    let error: String
    let message: String?
    let statusCode: Int?
    
    /// Use error message if available, fallback to message field
    var userMessage: String {
        return error
    }
}