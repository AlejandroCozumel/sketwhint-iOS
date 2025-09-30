import Foundation

// MARK: - Product Category Models

/// Product category with additional metadata for complete products like books
struct ProductCategory: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String                 // emoji icon
    let imageUrl: String?
    let color: String
    let tokenCost: Int
    let multipleOptions: Bool
    let maxOptionsCount: Int
    let isActive: Bool
    let isDefault: Bool
    let sortOrder: Int
    let createdAt: String
    let updatedAt: String
    
    // Product-specific fields
    let productType: String
    let draftEndpoint: String        // '/api/stories/drafts' for draft creation
    let generateEndpoint: String     // '/api/books/{draftId}/generate-images' for generation
    let browseEndpoint: String
    let requiresStoryFlow: Bool
    let supportedFormats: [String]
    let features: [String]
    let estimatedDuration: String
}

/// Response from /api/categories/products endpoint
struct ProductCategoriesResponse: Codable {
    let products: [ProductCategory]
    let count: Int
}

// MARK: - Product Service Error Types
enum ProductError: LocalizedError {
    case invalidURL
    case noToken
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noToken:
            return "Authentication required"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "Network error: \(code)"
        case .serverError(let message):
            return message
        }
    }
}