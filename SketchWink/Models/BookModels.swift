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
    let pdfUrl: String? // PDF download URL (available when book generation is complete)
    
    // Custom decoder to handle API sending isFavorite as Int (0/1) instead of Bool
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        coverImageUrl = try container.decode(String.self, forKey: .coverImageUrl)
        totalPages = try container.decode(Int.self, forKey: .totalPages)
        category = try container.decode(String.self, forKey: .category)
        
        // Handle isFavorite as either Bool or Int (0/1)
        if let boolValue = try? container.decode(Bool.self, forKey: .isFavorite) {
            isFavorite = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .isFavorite) {
            isFavorite = intValue != 0
        } else {
            isFavorite = false // default fallback
        }
        
        // Handle inFolder as either Bool or Int (0/1)
        if let boolValue = try? container.decode(Bool.self, forKey: .inFolder) {
            inFolder = boolValue
        } else if let intValue = try? container.decode(Int.self, forKey: .inFolder) {
            inFolder = intValue != 0
        } else {
            inFolder = false // default fallback
        }
        
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        createdBy = try container.decodeIfPresent(CreatedByProfile.self, forKey: .createdBy)
        pdfUrl = try container.decodeIfPresent(String.self, forKey: .pdfUrl)
    }
    
    // Custom encoder to maintain Encodable conformance
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(coverImageUrl, forKey: .coverImageUrl)
        try container.encode(totalPages, forKey: .totalPages)
        try container.encode(category, forKey: .category)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(inFolder, forKey: .inFolder)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(createdBy, forKey: .createdBy)
        try container.encodeIfPresent(pdfUrl, forKey: .pdfUrl)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, description, coverImageUrl, totalPages, category, isFavorite, inFolder, createdAt, updatedAt, createdBy, pdfUrl
    }
    
    // Regular initializer for creating instances manually (e.g., in previews)
    init(
        id: String,
        title: String,
        description: String? = nil,
        coverImageUrl: String,
        totalPages: Int,
        category: String,
        isFavorite: Bool = false,
        inFolder: Bool = false,
        createdAt: String,
        updatedAt: String,
        createdBy: CreatedByProfile? = nil,
        pdfUrl: String? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.coverImageUrl = coverImageUrl
        self.totalPages = totalPages
        self.category = category
        self.isFavorite = isFavorite
        self.inFolder = inFolder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.pdfUrl = pdfUrl
    }
    
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
    let text: String?
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

// MARK: - Book Themes & Focus Tags (Dynamic from Backend)

/// Book category metadata from /api/books/themes
struct BookCategory: Codable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let imageUrl: String?
    let color: String
}

/// Book theme option from /api/books/themes
struct BookThemeOption: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let imageUrl: String?
    let color: String?
    let style: String?
    let requiresCustomContent: Bool?
    let isDefault: Bool?
    let sortOrder: Int?
}

/// Response from /api/books/themes endpoint
struct BookThemesResponse: Codable {
    let category: BookCategory
    let themes: [BookThemeOption]
}

/// Book focus tag from /api/books/focus-tags
struct BookFocusTag: Codable, Identifiable {
    let id: String
    let value: String
    let name: String
    let icon: String
}

/// Response from /api/books/focus-tags endpoint
struct BookFocusTagsResponse: Codable {
    let focusTags: [BookFocusTag]
}
