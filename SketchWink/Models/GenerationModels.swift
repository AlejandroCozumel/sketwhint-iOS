import Foundation
import UIKit

// MARK: - Generation Category Models
struct GenerationCategory: Codable, Identifiable {
    let id: String  // "coloring_pages", "stickers", "wallpapers", "mandalas"
    let name: String
    let description: String
    let icon: String?
    let imageUrl: String?
    let color: String?
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
    let imageUrl: String?
    let color: String?
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
    let imageUrl: String?
    let color: String?
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
            icon: icon,
            imageUrl: imageUrl,
            color: color,
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
    let familyProfileId: String?  // Family profile ID (optional)
    let inputImage: String?  // Base64 encoded image for image-to-coloring conversion
    
    // MARK: - Convenience Initializers
    
    /// Initialize for text-based generation (no image upload)
    init(categoryId: String, optionId: String, prompt: String, quality: String? = nil, dimensions: String? = nil, maxImages: Int? = nil, model: String? = nil, familyProfileId: String? = nil) {
        self.categoryId = categoryId
        self.optionId = optionId
        self.prompt = prompt
        self.quality = quality
        self.dimensions = dimensions
        self.maxImages = maxImages
        self.model = model
        self.familyProfileId = familyProfileId
        self.inputImage = nil
    }
    
    /// Initialize for image-based generation (photo to coloring page)
    init(categoryId: String, optionId: String, prompt: String, inputImage: UIImage, quality: String? = nil, dimensions: String? = nil, maxImages: Int? = nil, model: String? = nil, familyProfileId: String? = nil) {
        self.categoryId = categoryId
        self.optionId = optionId
        self.prompt = prompt
        self.quality = quality
        self.dimensions = dimensions
        self.maxImages = maxImages
        self.model = model
        self.familyProfileId = familyProfileId
        
        // Process and convert image to base64
        let processedImage = inputImage.processForUpload(maxSize: 1024, quality: 0.7)
        self.inputImage = processedImage.toBase64String(quality: 0.7)
        
        #if DEBUG
        print("📷 CreateGenerationRequest: Image processed for upload")
        print("📐 CreateGenerationRequest: Original size: \(inputImage.size)")
        print("📐 CreateGenerationRequest: Processed size: \(processedImage.size)")
        if let inputImage = self.inputImage {
            print("📊 CreateGenerationRequest: Base64 length: \(inputImage.count) characters")
        }
        #endif
    }
}

struct Generation: Codable, Identifiable {
    let id: String
    let status: String  // "queued", "starting", "processing", "completing", "completed", "failed"
    let progress: Int?  // Optional - might not be in GET response
    let replicateId: String?
    let estimatedTimeMs: Int?  // Only in creation response
    let categoryId: String
    let optionId: String
    let title: String
    let description: String
    let userPrompt: String?  // Optional - not required for image uploads
    let tokensUsed: Int
    let quality: String
    let dimensions: String
    let modelVersion: String?  // Only present in completed generations
    let errorMessage: String?
    let images: [GeneratedImage]?  // Only in detailed response
    let createdAt: String
    let updatedAt: String
    // Resolved display names from backend
    let categoryName: String?
    let optionName: String?
}

struct GeneratedImage: Codable, Identifiable {
    let id: String
    let imageUrl: String
    let optionIndex: Int
    var isFavorite: Bool
    let originalUserPrompt: String?
    let enhancedPrompt: String?
    let wasEnhanced: Bool?
    let wasFromImageUpload: Bool?
    let modelUsed: String?
    let qualityUsed: String?
    let dimensionsUsed: String?
    let createdAt: String
    let generation: GenerationInfo?  // Only in gallery response
    let collections: [String]?       // Only in gallery response
    let createdBy: CreatedByProfile?  // NEW: Profile information for family display
    
    // UI helper for displaying creator information
    var creatorDisplayName: String {
        return createdBy?.profileName ?? "Unknown Profile"
    }
    
    // UI helper for checking if created by current profile
    var isCreatedByCurrentProfile: Bool {
        guard let currentProfileId = try? KeychainManager.shared.retrieveSelectedProfile(),
              let createdById = createdBy?.profileId else {
            return false
        }
        return currentProfileId == createdById
    }
}

/// Profile information for content creation tracking
struct CreatedByProfile: Codable {
    let profileId: String?      // Make optional to handle null values
    let profileName: String     // Keep non-optional since it's always provided
    let profileAvatar: String?
    
    /// UI helper for avatar display
    var displayAvatar: String {
        return profileAvatar ?? "👤"
    }
    
    /// Check if this is a legacy/unknown profile
    var isUnknownProfile: Bool {
        return profileId == nil
    }
}

struct GenerationInfo: Codable {
    let id: String
    let title: String
    let category: String
    let option: String
    let modelUsed: String
    let qualityUsed: String
    let createdAt: String?  // Optional for backward compatibility
}

// MARK: - User Settings Models
struct PromptEnhancementSettings: Codable {
    let promptEnhancementEnabled: Bool
}

struct PromptEnhancementResponse: Codable {
    let message: String
    let settings: PromptEnhancementSettings
}

// MARK: - Generation State for UI
enum GenerationState: Equatable {
    case idle
    case loading
    case generating(Generation)
    case completed(Generation)
    case failed(String)

    static func == (lhs: GenerationState, rhs: GenerationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading):
            return true
        case (.generating(let lhsGen), .generating(let rhsGen)):
            return lhsGen.id == rhsGen.id
        case (.completed(let lhsGen), .completed(let rhsGen)):
            return lhsGen.id == rhsGen.id
        case (.failed(let lhsMsg), .failed(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

// MARK: - Gallery Models
struct ImagesResponse: Codable {
    let images: [GeneratedImage]
    let total: Int
    let page: Int
    let limit: Int
    let filters: FilterInfo?
}

struct FilterInfo: Codable {
    let categories: [String]?
    let totalFavorites: Int?
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

// MARK: - Generation Progress Models (Shared)

/// Represents the real-time progress of a generation
struct GenerationProgress {
    let generationId: String
    let status: GenerationStatus
    let progress: Int
    let imageCount: Int
    let error: String?
    
    // UI helper for progress bar (0.0 to 1.0)
    var progressPercentage: Double {
        return Double(progress) / 100.0
    }
}

/// Standardized status enum for generations
enum GenerationStatus: String, Codable {
    case queued
    case starting
    case processing
    case completing
    case completed
    case failed
    case cancelled
    
    var icon: String {
        switch self {
        case .queued: return "⏳"
        case .starting: return "✨"
        case .processing: return "🎨"
        case .completing: return "⚡"
        case .completed: return "🎉"
        case .failed: return "❌"
        case .cancelled: return "🚫"
        }
    }
    
    var displayMessage: String {
        switch self {
        case .queued: return NSLocalizedString("progress.queued", comment: "")
        case .starting: return NSLocalizedString("progress.starting", comment: "")
        case .processing: return NSLocalizedString("progress.processing", comment: "")
        case .completing: return NSLocalizedString("progress.completing", comment: "")
        case .completed: return NSLocalizedString("progress.completed", comment: "")
        case .failed: return NSLocalizedString("progress.failed", comment: "")
        case .cancelled: return NSLocalizedString("progress.cancelled", comment: "")
        }
    }
}

/// Errors related to generation progress
enum GenerationProgressError: LocalizedError {
    case generationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .generationFailed(let message):
            return message
        }
    }
}