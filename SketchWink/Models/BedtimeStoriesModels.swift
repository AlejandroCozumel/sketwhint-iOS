import Foundation

// MARK: - Configuration Models

struct BedtimeStoriesConfig: Codable {
    let voices: [Voice]
    let speedOptions: [SpeedOption]
    let backgroundMusic: [BackgroundMusic]
    let defaults: Defaults
}

struct Voice: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let gender: String
    let isDefault: Bool
}

struct SpeedOption: Codable, Identifiable {
    var id: Double { value }
    let value: Double
    let label: String
    let description: String
    let isDefault: Bool?
}

struct BackgroundMusic: Codable {
    // Empty for now - Phase 2
}

struct Defaults: Codable {
    let voiceId: String
    let speed: Double
    let withBackgroundMusic: Bool
}

// MARK: - Theme Models

struct BedtimeThemeOption: Codable, Identifiable {
    let id: String
    let categoryId: String
    let name: String
    let description: String
    let style: String
    let isDefault: Bool?
    let sortOrder: Int
}

struct BedtimeThemeOptionsResponse: Codable {
    let options: [BedtimeThemeOption]
}

// MARK: - Draft Models

struct CreateBedtimeDraftRequest: Codable {
    let prompt: String
    let length: BedtimeStoryLength
    let optionId: String
    let characterName: String?
    let ageGroup: String?
}

enum BedtimeStoryLength: String, Codable, CaseIterable {
    case short = "short"
    case medium = "medium"
    case long = "long"

    var tokenCost: Int {
        switch self {
        case .short: return 5
        case .medium: return 8
        case .long: return 10
        }
    }

    var displayName: String {
        switch self {
        case .short: return "Short (2-3 min)"
        case .medium: return "Medium (4-5 min)"
        case .long: return "Long (6-8 min)"
        }
    }
}

struct BedtimeDraftResponse: Codable {
    let message: String
    let draft: BedtimeDraft
}

struct BedtimeDraft: Codable, Identifiable {
    let id: String
    let title: String
    var storyText: String
    let wordCount: Int
    let length: String
    let estimatedDuration: Int
    let tokenCost: Int
    let status: String
}

struct UpdateBedtimeDraftRequest: Codable {
    let storyText: String
    let title: String?
}

// MARK: - Generation Models

struct GenerateBedtimeStoryRequest: Codable {
    let draftId: String
    let voiceId: String
    let speed: Double
}

struct GenerateBedtimeStoryResponse: Codable {
    let message: String
    let story: BedtimeStory
}

// MARK: - Story Models

struct BedtimeStory: Codable, Identifiable {
    let id: String
    let title: String
    let storyText: String?
    let theme: String?
    let characterName: String?
    let ageGroup: String?
    let storyLength: String
    let duration: Int
    let wordCount: Int
    let imageUrl: String
    let audioUrl: String
    let voiceId: String?
    let speed: Double?
    var isFavorite: Bool
    let playCount: Int
    let status: String
    let createdAt: String
    let wordTimestamps: String? // JSON string with word-level timestamps for synchronized highlighting
}

// MARK: - Word Timestamp Models

struct WordTimestamp: Codable {
    let word: String
    let start: Double // Start time in seconds
    let end: Double   // End time in seconds
}

struct BedtimeStoriesResponse: Codable {
    let stories: [BedtimeStory]
    let pagination: BedtimeStoryPagination
}

struct BedtimeStoryPagination: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
}

struct SingleBedtimeStoryResponse: Codable {
    let story: BedtimeStory
}

struct BedtimeFavoriteResponse: Codable {
    let message: String
    let isFavorite: Bool
}

struct BedtimeDeleteResponse: Codable {
    let message: String
}
