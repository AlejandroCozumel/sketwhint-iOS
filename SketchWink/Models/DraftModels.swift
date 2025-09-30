import Foundation

// MARK: - Draft Creation Models

/// Story type options for draft creation
enum StoryType: String, CaseIterable, Codable {
    case bedtimeStory = "bedtime_story"
    case adventureStory = "adventure_story"
    case educationalStory = "educational_story"
    case friendshipStory = "friendship_story"
    case fantasyStory = "fantasy_story"
    case coloringBook = "coloring_book"
    
    var displayName: String {
        switch self {
        case .bedtimeStory: return "Bedtime Story"
        case .adventureStory: return "Adventure Story"
        case .educationalStory: return "Educational Story"
        case .friendshipStory: return "Friendship Story"
        case .fantasyStory: return "Fantasy Story"
        case .coloringBook: return "Coloring Book"
        }
    }
    
    var description: String {
        switch self {
        case .bedtimeStory: return "Peaceful, calming stories for bedtime"
        case .adventureStory: return "Exciting adventures and quests"
        case .educationalStory: return "Learning-focused stories"
        case .friendshipStory: return "Stories about friendship and relationships"
        case .fantasyStory: return "Magical and fantastical tales"
        case .coloringBook: return "Stories designed for coloring activities"
        }
    }
    
    var icon: String {
        switch self {
        case .bedtimeStory: return "moon.stars.fill"
        case .adventureStory: return "map.fill"
        case .educationalStory: return "graduationcap.fill"
        case .friendshipStory: return "heart.fill"
        case .fantasyStory: return "sparkles"
        case .coloringBook: return "paintbrush.fill"
        }
    }
}

/// Age group options for stories
enum AgeGroup: String, CaseIterable, Codable {
    case toddler = "2-4"
    case preschool = "4-6"
    case earlyElementary = "6-8"
    case elementary = "8+"
    
    var displayName: String {
        return rawValue
    }
    
    var description: String {
        switch self {
        case .toddler: return "Simple words, basic concepts"
        case .preschool: return "Adventure and learning focused"
        case .earlyElementary: return "More complex plots and themes"
        case .elementary: return "Advanced themes and vocabulary"
        }
    }
}

/// Focus tags for story themes
enum FocusTag: String, CaseIterable, Codable {
    case magicImagination = "Magic & Imagination"
    case adventureProblemSolving = "Adventure & Problem Solving"
    case natureAnimals = "Nature & Animals"
    case emotionsFeelings = "Emotions & Feelings"
    case familyLove = "Family & Love"
    case learningEducation = "Learning & Education"
    case friendshipSocialSkills = "Friendship & Social Skills"
    
    var displayName: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .magicImagination: return "sparkles"
        case .adventureProblemSolving: return "map.fill"
        case .natureAnimals: return "leaf.fill"
        case .emotionsFeelings: return "heart.fill"
        case .familyLove: return "house.fill"
        case .learningEducation: return "book.fill"
        case .friendshipSocialSkills: return "person.2.fill"
        }
    }
}

/// Request model for creating a story draft
struct CreateDraftRequest: Codable {
    let theme: String
    let storyType: StoryType
    let ageGroup: AgeGroup
    let pageCount: Int
    let focusTags: [FocusTag]?
    let customFocus: String?
    
    enum CodingKeys: String, CodingKey {
        case theme
        case storyType = "story_type"
        case ageGroup = "age_group"
        case pageCount = "page_count"
        case focusTags = "focus_tags"
        case customFocus = "custom_focus"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(theme, forKey: .theme)
        try container.encode(storyType.rawValue, forKey: .storyType)
        try container.encode(ageGroup.rawValue, forKey: .ageGroup)
        try container.encode(pageCount, forKey: .pageCount)
        
        if let focusTags = focusTags {
            try container.encode(focusTags.map { $0.rawValue }, forKey: .focusTags)
        }
        try container.encodeIfPresent(customFocus, forKey: .customFocus)
    }
}

/// Story page structure
struct StoryPage: Codable, Identifiable {
    let id = UUID()
    let pageNumber: Int
    let title: String
    let text: String
    let sceneDescription: String
    let characters: [String]
    
    enum CodingKeys: String, CodingKey {
        case pageNumber = "page_number"
        case title
        case text
        case sceneDescription = "scene_description"
        case characters
    }
}

/// Character description structure
struct CharacterDescription: Codable {
    let physicalAppearance: [String]
    let personalityTraits: [String]
    
    enum CodingKeys: String, CodingKey {
        case physicalAppearance = "Physical appearance details"
        case personalityTraits = "Personality traits"
    }
}

/// Story outline structure
struct StoryOutline: Codable {
    let title: String
    let mainCharacters: [String]
    let pages: [StoryPage]
    
    enum CodingKeys: String, CodingKey {
        case title
        case mainCharacters = "main_characters"
        case pages
    }
}

/// Complete draft response from API
struct StoryDraft: Codable, Identifiable {
    let id: String
    let title: String
    let theme: String
    let storyOutline: StoryOutline
    let characterDescriptions: [String: CharacterDescription]
    let tokensCost: Int
    let status: String
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case theme
        case storyOutline = "story_outline"
        case characterDescriptions = "character_descriptions"
        case tokensCost = "tokens_cost"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Response from draft creation
struct CreateDraftResponse: Codable {
    let draft: StoryDraft
    let message: String?
}

/// Response from getting all drafts
struct GetDraftsResponse: Codable {
    let drafts: [StoryDraft]
    let total: Int
}

/// Update draft request
struct UpdateDraftRequest: Codable {
    let title: String?
    let pageTexts: [String]?
    
    enum CodingKeys: String, CodingKey {
        case title
        case pageTexts = "page_texts"
    }
}

/// Generate book from draft request
struct GenerateBookFromDraftRequest: Codable {
    let model: String?
    let quality: String?
    let dimensions: String?
    
    init(model: String = "seedream", quality: String = "standard", dimensions: String = "a4") {
        self.model = model
        self.quality = quality
        self.dimensions = dimensions
    }
}

/// Generate book response
struct GenerateBookResponse: Codable {
    let bookId: String
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case bookId = "book_id"
        case message
    }
}

// MARK: - Draft Service Error Types
enum DraftError: LocalizedError {
    case invalidURL
    case noToken
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case validationError(String)
    
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
        case .validationError(let message):
            return message
        }
    }
}