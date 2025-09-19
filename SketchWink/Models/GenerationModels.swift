import Foundation

// MARK: - Generation Category Models
struct GenerationCategory: Codable, Identifiable {
    let id: String  // "coloring_pages", "stickers", "wallpapers", "mandalas"
    let name: String
    let description: String
    let icon: String
    let tokenCost: Int
    let multipleOptions: Bool
    let maxOptionsCount: Int
    let isActive: Bool
    let isDefault: Bool
    let sortOrder: Int
}

struct GenerationOption: Codable, Identifiable {
    let id: String
    let categoryId: String
    let name: String
    let description: String
    let promptTemplate: String
    let style: String
    let isActive: Bool
    let isDefault: Bool
    let sortOrder: Int
}

struct CategoryWithOptions: Codable, Identifiable {
    let category: GenerationCategory
    let options: [GenerationOption]
    
    var id: String { category.id }
    
    // Custom init for when category and options are at the same level
    init(from category: GenerationCategory, options: [GenerationOption]) {
        self.category = category
        self.options = options
    }
    
    // Regular codable init
    init(category: GenerationCategory, options: [GenerationOption]) {
        self.category = category
        self.options = options
    }
}

// Wrapper for API response that includes categories array and count
struct CategoriesResponse: Codable {
    let categories: [CategoryWithOptionsFlat]
    let count: Int
}

// Model that matches your API structure where category and options are at the same level
struct CategoryWithOptionsFlat: Codable {
    let id: String
    let name: String
    let description: String
    let icon: String?
    let tokenCost: Int
    let multipleOptions: Bool
    let maxOptionsCount: Int
    let isActive: Bool
    let isDefault: Bool
    let sortOrder: Int
    let createdAt: String
    let updatedAt: String
    let options: [GenerationOption]
    
    // Convert to our expected format
    func toCategoryWithOptions() -> CategoryWithOptions {
        let category = GenerationCategory(
            id: id,
            name: name,
            description: description,
            icon: icon ?? "",
            tokenCost: tokenCost,
            multipleOptions: multipleOptions,
            maxOptionsCount: maxOptionsCount,
            isActive: isActive,
            isDefault: isDefault,
            sortOrder: sortOrder
        )
        
        return CategoryWithOptions(category: category, options: options)
    }
}

// MARK: - Generation Request/Response Models
struct CreateGenerationRequest: Codable {
    let categoryId: String
    let optionId: String
    let prompt: String
    let quality: String?     // "standard", "high", "ultra"
    let dimensions: String?  // "1:1", "2:3", "3:2", "a4"
    let maxImages: Int?      // 1-4 images per generation
    let model: String?       // "seedream", "flux"
}

struct Generation: Codable, Identifiable {
    let id: String
    let status: String  // "processing", "completed", "failed"
    let categoryId: String
    let optionId: String
    let title: String
    let description: String
    let userPrompt: String
    let tokensUsed: Int
    let quality: String
    let dimensions: String
    let modelVersion: String
    let errorMessage: String?
    let images: [GeneratedImage]?
    let createdAt: String
    let updatedAt: String
}

struct GeneratedImage: Codable, Identifiable {
    let id: String
    let imageUrl: String  // Permanent Cloudflare R2 URL
    let optionIndex: Int  // 0-3 for multiple variations
    let isFavorite: Bool
    let originalUserPrompt: String
    let enhancedPrompt: String?
    let wasEnhanced: Bool
    let modelUsed: String
    let qualityUsed: String
    let dimensionsUsed: String
    let createdAt: String
}

// MARK: - User Settings Models
struct PromptEnhancementSettings: Codable {
    let promptEnhancementEnabled: Bool
}

// MARK: - Generation State for UI
enum GenerationState {
    case idle
    case loading
    case generating(Generation)
    case completed(Generation)
    case failed(String)
}

// MARK: - Gallery Models
struct ImagesResponse: Codable {
    let images: [GeneratedImage]
    let pagination: PaginationInfo
    let totalCount: Int
}

struct PaginationInfo: Codable {
    let currentPage: Int
    let totalPages: Int
    let hasNext: Bool
    let hasPrev: Bool
}

// MARK: - Extensions for UI
extension GenerationCategory {
    var colorTheme: String {
        switch id {
        case "coloring_pages":
            return "coloringPagesColor"
        case "stickers":
            return "stickersColor"
        case "wallpapers":
            return "wallpapersColor"
        case "mandalas":
            return "mandalaColor"
        default:
            return "primaryBlue"
        }
    }
}

extension GenerationOption {
    var displayName: String {
        return name
    }
    
    var displayDescription: String {
        return description.isEmpty ? style : description
    }
}