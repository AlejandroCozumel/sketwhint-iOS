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
    let aiGenerated: Bool
    
    enum CodingKeys: String, CodingKey {
        case theme
        case storyType = "storyType"
        case ageGroup = "ageGroup"
        case pageCount = "pageCount"
        case focusTags = "focusTags"
        case customFocus = "customFocus"
        case aiGenerated = "aiGenerated"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(theme, forKey: .theme)
        try container.encode(storyType.rawValue, forKey: .storyType)
        try container.encode(ageGroup.rawValue, forKey: .ageGroup)
        try container.encode(pageCount, forKey: .pageCount)
        try container.encode(aiGenerated, forKey: .aiGenerated)

        if let focusTags = focusTags {
            try container.encode(focusTags.map { $0.rawValue }, forKey: .focusTags)
        } else {
            try container.encode([String](), forKey: .focusTags) // Empty array instead of null
        }

        if let customFocus = customFocus, !customFocus.isEmpty {
            try container.encode(customFocus, forKey: .customFocus)
        } else {
            try container.encode("", forKey: .customFocus) // Empty string instead of null
        }
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
        case pageNumber = "pageNumber"
        case title
        case text
        case sceneDescription = "sceneDescription"
        case characters
    }
}

/// Character description structure - matches backend response exactly
struct CharacterDescription: Codable {
    let physicalAppearance: [String]
    let personalityTraits: [String]
    let roleInStory: String

    // Custom decoder to handle both old and new backend structures
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)

        // Try lowercase keys first (new format)
        if let physicalDict = try? container.decodeIfPresent([String: AnyCodable].self, forKey: DynamicCodingKeys(stringValue: "physicalAppearance")!) {
            // Convert dictionary to array of descriptive strings
            var descriptions: [String] = []

            if let species = physicalDict["species"]?.value as? String {
                descriptions.append("Species: \(species)")
            }
            if let breed = physicalDict["breed"]?.value as? String {
                descriptions.append("Breed: \(breed)")
            }
            if let furColor = physicalDict["furColor"]?.value as? String {
                descriptions.append("Fur: \(furColor)")
            }
            if let eyeColor = physicalDict["eyeColor"]?.value as? String {
                descriptions.append("Eyes: \(eyeColor)")
            }
            if let size = physicalDict["size"]?.value as? String {
                descriptions.append("Size: \(size)")
            }
            if let features = physicalDict["distinctiveFeatures"]?.value as? [String] {
                descriptions.append(contentsOf: features)
            }

            self.physicalAppearance = descriptions.isEmpty ? ["Friendly character"] : descriptions
        }
        // Try old format with capitalized keys
        else if let physicalString = try? container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "PhysicalAppearance")!) {
            self.physicalAppearance = physicalString.components(separatedBy: ". ").filter { !$0.isEmpty }
        }
        // Fallback
        else {
            self.physicalAppearance = ["Friendly character"]
        }

        // Try lowercase keys first (new format)
        if let traits = try? container.decodeIfPresent([String].self, forKey: DynamicCodingKeys(stringValue: "personalityTraits")!) {
            self.personalityTraits = traits
        }
        // Try old format with capitalized keys
        else if let traits = try? container.decodeIfPresent([String].self, forKey: DynamicCodingKeys(stringValue: "PersonalityTraits")!) {
            self.personalityTraits = traits
        }
        // Fallback
        else {
            self.personalityTraits = ["Friendly", "Brave", "Kind"]
        }

        // Try lowercase keys first (new format)
        if let role = try? container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "roleInStory")!) {
            self.roleInStory = role
        }
        // Try old format with capitalized keys
        else if let role = try? container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "RoleInStory")!) {
            self.roleInStory = role
        }
        // Fallback
        else {
            self.roleInStory = "Important character in the story"
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)
        try container.encode(physicalAppearance.joined(separator: ". "), forKey: DynamicCodingKeys(stringValue: "physicalAppearance")!)
        try container.encode(personalityTraits, forKey: DynamicCodingKeys(stringValue: "personalityTraits")!)
        try container.encode(roleInStory, forKey: DynamicCodingKeys(stringValue: "roleInStory")!)
    }
}

// Helper for dynamic coding keys
struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

// Helper for decoding any JSON value
struct AnyCodable: Codable {
    let value: Any

    init(value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable(value: $0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable(value: $0) })
        default:
            try container.encodeNil()
        }
    }
}

/// Story outline structure
struct StoryOutline: Codable {
    let title: String
    let mainCharacters: [String]
    let setting: String
    let theme: String
    let moralLesson: String
    let pages: [StoryPage]

    enum CodingKeys: String, CodingKey {
        case title
        case mainCharacters = "mainCharacters"
        case setting
        case theme
        case moralLesson = "moralLesson"
        case pages
    }
}

/// Complete draft response from API
struct StoryDraft: Codable, Identifiable {
    let id: String
    let userId: String
    let familyProfileId: String?
    let templateId: String?
    let productType: String
    let title: String
    let theme: String
    let ageGroup: String
    let pageCount: Int
    let focusTags: [String]
    let customFocus: String?
    let aiGenerated: Bool
    let storyOutline: StoryOutline
    let pageTexts: [String]
    let characterDescriptions: [String: CharacterDescription]
    let artStyle: String?
    let status: String
    let tokensCost: Int
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case familyProfileId
        case templateId
        case productType
        case title
        case theme
        case ageGroup
        case pageCount
        case focusTags
        case customFocus
        case aiGenerated
        case storyOutline = "storyOutline"
        case pageTexts
        case characterDescriptions = "characterDescriptions"
        case artStyle
        case status
        case tokensCost = "tokensCost"
        case createdAt = "createdAt"
        case updatedAt = "updatedAt"
    }
}

/// Response from draft creation - matches actual backend format
struct CreateDraftResponse: Codable {
    let success: Bool
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
        case pageTexts = "pageTexts"
    }
}

/// Generate book from draft request
struct GenerateBookFromDraftRequest: Codable {
    let draftId: String?
    let confirm: Bool
    let model: String?
    let quality: String?
    let dimensions: String?

    init(draftId: String? = nil, confirm: Bool = true, model: String = "seedream", quality: String = "standard", dimensions: String = "a4") {
        self.draftId = draftId
        self.confirm = confirm
        self.model = model
        self.quality = quality
        self.dimensions = dimensions
    }
}

/// Generate book response
struct GenerateBookResponse: Codable {
    let productId: String
    let status: String
    let tokensUsed: Int
    let estimatedCompletion: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case productId
        case status
        case tokensUsed
        case estimatedCompletion
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