import Foundation

// MARK: - Folder Models
// Note: CreatedBy and Generation types are imported from APIModels.swift

struct UserFolder: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let color: String
    let icon: String
    let imageCount: Int
    let sortOrder: Int
    let createdAt: String
    let updatedAt: String
    let createdBy: CreatedBy
    
    // Make hashable for sheet presentation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: UserFolder, rhs: UserFolder) -> Bool {
        lhs.id == rhs.id
    }
}

struct FolderImage: Codable, Identifiable {
    let id: String
    let imageUrl: String
    let optionIndex: Int
    let isFavorite: Bool
    let movedAt: String
    let notes: String?
    let generation: GenerationInfo  // Use GenerationInfo instead of Generation to match API response
    let createdBy: CreatedBy
}

// MARK: - API Request/Response Models

struct CreateFolderRequest: Codable {
    let name: String
    let description: String?
    let color: String
    let icon: String
}

struct CreateFolderResponse: Codable {
    let folder: UserFolder
}

struct GetFoldersResponse: Codable {
    let folders: [UserFolder]
}

struct FolderImagesResponse: Codable {
    let images: [FolderImage]
    let total: Int
    let page: Int
    let limit: Int
    let filters: FolderFilters?  // Optional filters object
}

struct FolderFilters: Codable {
    let categories: [String]?
    let totalFavorites: Int?
}

struct FolderInfo: Codable {
    let id: String
    let name: String
}

struct MoveImagesToFolderRequest: Codable {
    let imageIds: [String]
    let notes: String?
}

struct MoveImagesToFolderResponse: Codable {
    let message: String
    let moved: Int
    let skipped: Int
}

struct RemoveImagesFromFolderRequest: Codable {
    let imageIds: [String]
}

struct RemoveImagesFromFolderResponse: Codable {
    let message: String
    let removed: Int
}

struct UpdateFolderRequest: Codable {
    let name: String?
    let description: String?
    let color: String?
    let icon: String?
}

struct UpdateFolderResponse: Codable {
    let folder: UserFolder
}

struct DeleteFolderResponse: Codable {
    let message: String
}

// MARK: - Folder Service Errors

enum FolderError: Error, LocalizedError {
    case profileSelectionRequired
    case folderNotFound
    case accessDenied
    case invalidData
    case networkError(String)
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .profileSelectionRequired:
            return "Please select a profile to manage folders"
        case .folderNotFound:
            return "Folder not found"
        case .accessDenied:
            return "You don't have permission to access this folder"
        case .invalidData:
            return "Invalid folder data"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return message
        }
    }
}

// MARK: - Folder Constants

struct FolderConstants {
    static let defaultColors = [
        "#8B5CF6", // Purple
        "#10B981", // Emerald
        "#F59E0B", // Amber
        "#EF4444", // Red
        "#3B82F6", // Blue
        "#EC4899", // Pink
        "#06B6D4", // Cyan
        "#84CC16", // Lime
        "#F97316", // Orange
        "#8B5A2B"  // Brown
    ]
    
    static let defaultIcons = [
        "📁", "🎨", "📸", "🌟", "❤️",
        "🎭", "🌈", "🦄", "🎪", "🎨",
        "🎯", "🎲", "🧩", "🎪", "🎨"
    ]
    
    static let maxNameLength = 50
    static let maxDescriptionLength = 200
    static let maxFoldersPerUser = 50
}

// MARK: - Folder Extensions

extension UserFolder {
    var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: createdAt) {
            return formatter.string(from: date)
        }
        return "Unknown"
    }
    
    var formattedImageCount: String {
        if imageCount == 0 {
            return "Empty"
        } else if imageCount == 1 {
            return "1 image"
        } else {
            return "\(imageCount) images"
        }
    }
    
    var isEmpty: Bool {
        imageCount == 0
    }
}

extension FolderImage {
    var formattedMovedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: movedAt) {
            return formatter.string(from: date)
        }
        return "Unknown"
    }
}