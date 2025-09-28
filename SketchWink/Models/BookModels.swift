import Foundation

// MARK: - Book Models

/// Story book model from /api/books endpoint
struct StoryBook: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let coverImageUrl: String
    let totalPages: Int
    let category: String
    var isFavorite: Bool
    let inFolder: Bool
    let createdAt: String
    let updatedAt: String
    let createdBy: CreatedByProfile?
    
    /// UI helper for creator display
    var creatorDisplayName: String {
        return createdBy?.profileName ?? "Unknown Profile"
    }
    
    /// UI helper for checking if created by current profile
    var isCreatedByCurrentProfile: Bool {
        guard let currentProfileId = try? KeychainManager.shared.retrieveSelectedProfile(),
              let createdById = createdBy?.profileId else {
            return false
        }
        return currentProfileId == createdById
    }
    
    /// Format creation date for display
    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        
        if let date = formatter.date(from: createdAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        
        return createdAt
    }
}

/// Response from /api/books endpoint
struct BooksResponse: Codable {
    let books: [StoryBook]
    let total: Int
    let page: Int
    let limit: Int
}

/// Book page model for reading experience
struct BookPage: Codable, Identifiable {
    let pageNumber: Int
    let imageId: String
    let imageUrl: String
    var isFavorite: Bool
    
    var id: String { imageId }
}

/// Book with pages from /api/books/{id}/pages endpoint
struct BookWithPages: Codable {
    let book: StoryBook
    let pages: [BookPage]
}

// MARK: - Book Management Requests

/// Move book to folder request
struct MoveBookToFolderRequest: Codable {
    let folderId: String
    let notes: String?
}

/// Move book to folder response
struct MoveBookToFolderResponse: Codable {
    let message: String
    let success: Bool
}