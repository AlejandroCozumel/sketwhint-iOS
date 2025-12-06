import Foundation
import Combine

class DraftService: ObservableObject {
    static let shared = DraftService()

    private let baseURL = AppConfig.API.baseURL
    @Published var drafts: [StoryDraft] = []
    @Published var isLoading = false
    @Published var error: String?

    // Use real OpenAI API - backend has full story generation implemented
    private let useMockData = false

    private init() {}
    
    // MARK: - Draft Creation
    
    /// Create a new story draft
    func createDraft(_ request: CreateDraftRequest) async throws -> CreateDraftResponse {
        print("📝 DraftService: Creating story draft")
        print("📋 Theme: \(request.theme)")
        print("📋 Story Type: \(request.storyType.displayName)")
        print("📋 Age Group: \(request.ageGroup.displayName)")
        print("📋 Page Count: \(request.pageCount)")

        // Use mock data in development mode (currently disabled - using real API)
        if useMockData {
            return try await createMockDraft(from: request)
        }

        let endpoint = "\(baseURL)/stories/drafts"

        guard let url = URL(string: endpoint) else {
            throw DraftError.invalidURL
        }

        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw DraftError.noToken
        }

        print("🔗 Request URL: \(endpoint)")

        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add profile header for family profile support
        if let currentProfile = ProfileService.shared.currentProfile {
            httpRequest.setValue(currentProfile.id, forHTTPHeaderField: "X-Profile-ID")
        }

        let requestData = try JSONEncoder().encode(request)
        httpRequest.httpBody = requestData

        #if DEBUG
        if let requestString = String(data: requestData, encoding: .utf8) {
            print("📤 Draft Request: \(requestString)")
        }
        #endif

        let (data, response) = try await APIRequestHelper.shared.performRequest(httpRequest)

        #if DEBUG
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Draft Response: \(responseString)")
        }
        #endif

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DraftError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            // Try to decode API error message first, fallback to generic error
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw DraftError.serverError(apiError.userMessage)
            } else {
                throw DraftError.httpError(httpResponse.statusCode)
            }
        }

        let draftResponse = try JSONDecoder().decode(CreateDraftResponse.self, from: data)
        print("✅ DraftService: Successfully created draft with ID: \(draftResponse.draft.id)")

        return draftResponse
    }

    /// Generate book from draft (creates images for all pages)
    func generateBookFromDraft(draft: StoryDraft, storyType: String) async throws -> String {
        let endpoint = "\(baseURL)/books/generate"

        guard let url = URL(string: endpoint) else {
            throw DraftError.invalidURL
        }

        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw DraftError.noToken
        }

        // Build request body - omit customFocus if nil or empty
        var requestBody: [String: Any] = [
            "storyType": storyType,
            "theme": draft.theme,
            "ageGroup": draft.ageGroup,
            "pageCount": draft.pageCount,
            "focusTags": draft.focusTags,
            "artStyle": draft.artStyle as Any,
            "quality": "standard",
            "model": "seedream",
            "dimensions": "a4",
            "autoGenerate": true
        ]

        // Only add customFocus if it has a value (omit if nil or empty)
        if let customFocus = draft.customFocus, !customFocus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            requestBody["customFocus"] = customFocus as Any
        }

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        print("📖 DraftService: Generating book from draft")
        print("🔗 Request URL: \(endpoint)")
        print("📤 Request body: \(String(data: jsonData, encoding: .utf8) ?? "Unable to encode")")

        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        httpRequest.httpBody = jsonData

        // Add profile header for family profile support
        if let currentProfile = ProfileService.shared.currentProfile {
            httpRequest.setValue(currentProfile.id, forHTTPHeaderField: "X-Profile-ID")
            print("📋 Profile ID header set: \(currentProfile.id)")
            print("📋 Profile name: \(currentProfile.name)")
        } else {
            print("⚠️ WARNING: No current profile found! X-Profile-ID header NOT set")
        }

        let (data, response) = try await APIRequestHelper.shared.performRequest(httpRequest)

        #if DEBUG
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Book Generation Response: \(responseString)")
        }
        #endif

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DraftError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            // Try to decode API error message first, fallback to generic error
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw DraftError.serverError(apiError.userMessage)
            } else {
                throw DraftError.httpError(httpResponse.statusCode)
            }
        }

        // Decode response to get book ID
        struct GenerateBookResponse: Codable {
            let success: Bool
            let bookId: String
            let message: String?
        }

        let bookResponse = try JSONDecoder().decode(GenerateBookResponse.self, from: data)
        print("✅ DraftService: Successfully started book generation. Book ID: \(bookResponse.bookId)")

        return bookResponse.bookId
    }

    // MARK: - Draft Management
    
    /// Get all user drafts
    func getUserDrafts() async throws -> GetDraftsResponse {
        let endpoint = "\(baseURL)/stories/drafts"
        
        guard let url = URL(string: endpoint) else {
            throw DraftError.invalidURL
        }
        
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw DraftError.noToken
        }
        
        print("📚 DraftService: Loading user drafts")
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await APIRequestHelper.shared.performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DraftError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw DraftError.serverError(apiError.userMessage)
            } else {
                throw DraftError.httpError(httpResponse.statusCode)
            }
        }
        
        let draftsResponse = try JSONDecoder().decode(GetDraftsResponse.self, from: data)
        print("✅ DraftService: Successfully loaded \(draftsResponse.drafts.count) drafts")
        
        return draftsResponse
    }
    
    /// Get specific draft by ID
    func getDraft(id: String) async throws -> StoryDraft {
        let endpoint = "\(baseURL)/stories/drafts/\(id)"
        
        guard let url = URL(string: endpoint) else {
            throw DraftError.invalidURL
        }
        
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw DraftError.noToken
        }
        
        print("📖 DraftService: Loading draft \(id)")
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await APIRequestHelper.shared.performRequest(request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DraftError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw DraftError.serverError(apiError.userMessage)
            } else {
                throw DraftError.httpError(httpResponse.statusCode)
            }
        }
        
        struct DraftWrapper: Codable {
            let draft: StoryDraft
        }
        let draftResponse = try JSONDecoder().decode(DraftWrapper.self, from: data)
        let draft = draftResponse.draft
        
        print("✅ DraftService: Successfully loaded draft \(draft.title)")
        return draft
    }
    
    /// Update existing draft
    func updateDraft(id: String, updates: UpdateDraftRequest) async throws -> StoryDraft {
        let endpoint = "\(baseURL)/stories/drafts/\(id)"
        
        guard let url = URL(string: endpoint) else {
            throw DraftError.invalidURL
        }
        
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw DraftError.noToken
        }
        
        print("✏️ DraftService: Updating draft \(id)")
        
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "PUT"
        httpRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        httpRequest.httpBody = try JSONEncoder().encode(updates)
        
        let (data, response) = try await APIRequestHelper.shared.performRequest(httpRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DraftError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw DraftError.serverError(apiError.userMessage)
            } else {
                throw DraftError.httpError(httpResponse.statusCode)
            }
        }
        
        struct UpdateDraftWrapper: Codable {
            let draft: StoryDraft
        }
        let draftResponse = try JSONDecoder().decode(UpdateDraftWrapper.self, from: data)
        let draft = draftResponse.draft
        
        print("✅ DraftService: Successfully updated draft")
        return draft
    }
    
    /// Regenerate story content for existing draft
    func regenerateDraft(id: String) async throws -> StoryDraft {
        let endpoint = "\(baseURL)/stories/drafts/\(id)/regenerate"
        
        guard let url = URL(string: endpoint) else {
            throw DraftError.invalidURL
        }
        
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw DraftError.noToken
        }
        
        print("🔄 DraftService: Regenerating draft \(id)")
        
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await APIRequestHelper.shared.performRequest(httpRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DraftError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw DraftError.serverError(apiError.userMessage)
            } else {
                throw DraftError.httpError(httpResponse.statusCode)
            }
        }
        
        struct RegenerateDraftWrapper: Codable {
            let draft: StoryDraft
        }
        let draftResponse = try JSONDecoder().decode(RegenerateDraftWrapper.self, from: data)
        let draft = draftResponse.draft
        
        print("✅ DraftService: Successfully regenerated draft")
        return draft
    }
    
    /// Delete draft
    func deleteDraft(id: String) async throws {
        let endpoint = "\(baseURL)/stories/drafts/\(id)"
        
        guard let url = URL(string: endpoint) else {
            throw DraftError.invalidURL
        }
        
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw DraftError.noToken
        }
        
        print("🗑️ DraftService: Deleting draft \(id)")
        
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "DELETE"
        httpRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await APIRequestHelper.shared.performRequest(httpRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DraftError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw DraftError.serverError(apiError.userMessage)
            } else {
                throw DraftError.httpError(httpResponse.statusCode)
            }
        }
        
        print("✅ DraftService: Successfully deleted draft")
    }
    
    // MARK: - Book Generation from Draft
    
    /// Generate book from existing draft
    func generateBookFromDraft(draftId: String, options: GenerateBookFromDraftRequest = GenerateBookFromDraftRequest()) async throws -> GenerateBookResponse {
        let endpoint = "\(baseURL)/stories/generate-book"
        
        guard let url = URL(string: endpoint) else {
            throw DraftError.invalidURL
        }
        
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw DraftError.noToken
        }
        
        print("🎨 DraftService: Generating book from draft \(draftId)")
        print("🔧 Options: model=\(options.model ?? "default"), quality=\(options.quality ?? "default"), dimensions=\(options.dimensions ?? "default")")
        
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add profile header for family profile support
        if let currentProfile = ProfileService.shared.currentProfile {
            httpRequest.setValue(currentProfile.id, forHTTPHeaderField: "X-Profile-ID")
        }
        
        // Create request with draftId included
        let requestWithDraftId = GenerateBookFromDraftRequest(
            draftId: draftId,
            confirm: true,
            model: options.model ?? "seedream",
            quality: options.quality ?? "standard",
            dimensions: options.dimensions ?? "a4"
        )

        httpRequest.httpBody = try JSONEncoder().encode(requestWithDraftId)
        
        let (data, response) = try await APIRequestHelper.shared.performRequest(httpRequest)
        
        #if DEBUG
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Generate Book Response: \(responseString)")
        }
        #endif
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DraftError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw DraftError.serverError(apiError.userMessage)
            } else {
                throw DraftError.httpError(httpResponse.statusCode)
            }
        }
        
        let bookResponse = try JSONDecoder().decode(GenerateBookResponse.self, from: data)
        print("✅ DraftService: Successfully started book generation with ID: \(bookResponse.productId)")
        
        return bookResponse
    }
    
    // MARK: - Published Data Management
    
    /// Load drafts into published property
    func loadDrafts() async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            let response = try await getUserDrafts()
            await MainActor.run {
                drafts = response.drafts
                isLoading = false
            }
            print("✅ DraftService: Loaded \(response.drafts.count) drafts")
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                isLoading = false
            }
            print("❌ DraftService: Error loading drafts - \(error)")
        }
    }
    
    /// Clear drafts
    func clearDrafts() {
        drafts.removeAll()
        error = nil
    }
    
    /// Find draft by ID
    func getDraft(by id: String) -> StoryDraft? {
        return drafts.first { $0.id == id }
    }
    
    // MARK: - Validation Helpers
    
    /// Validate draft creation request
    func validateDraftRequest(_ request: CreateDraftRequest) -> String? {
        // Theme validation (3-200 characters)
        let trimmedTheme = request.theme.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTheme.count < 3 {
            return "Story theme must be at least 3 characters long"
        }
        if trimmedTheme.count > 200 {
            return "Story theme must be less than 200 characters"
        }

        // Page count validation (4-20 pages, recommended 4-8)
        if request.pageCount < 4 {
            return "Story must have at least 4 pages"
        }
        if request.pageCount > 20 {
            return "Story cannot have more than 20 pages"
        }

        return nil // Valid
    }

    // MARK: - Mock Data for Development

    /// Create mock draft for development when backend endpoints aren't ready
    private func createMockDraft(from request: CreateDraftRequest) async throws -> CreateDraftResponse {
        print("🎭 DraftService: Using mock data (backend endpoints not implemented)")

        // Simulate API delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        let mockDraft = generateMockStoryDraft(from: request)

        print("✅ DraftService: Mock draft created with ID: \(mockDraft.id)")

        return CreateDraftResponse(
            success: true,
            draft: mockDraft,
            message: "Mock story draft created successfully"
        )
    }

    /// Generate mock story content based on user request
    private func generateMockStoryDraft(from request: CreateDraftRequest) -> StoryDraft {
        let theme = request.theme
        let storyType = request.storyType
        let ageGroup = request.ageGroup
        let pageCount = request.pageCount

        // Generate mock story title
        let mockTitle = generateMockTitle(theme: theme, storyType: storyType)

        // Generate mock pages
        let mockPages = generateMockPages(theme: theme, storyType: storyType, pageCount: pageCount)

        // Generate mock characters
        let mockCharacters = generateMockCharacters(theme: theme)

        let mockOutline = StoryOutline(
            title: mockTitle,
            mainCharacters: Array(mockCharacters.keys),
            setting: "A magical place where \(theme) comes to life",
            theme: "Adventure and friendship",
            moralLesson: "Courage and kindness lead to wonderful discoveries",
            pages: mockPages
        )

        return StoryDraft(
            id: UUID().uuidString,
            userId: "mock-user-id",
            familyProfileId: nil,
            templateId: nil,
            productType: storyType.rawValue,
            title: mockTitle,
            theme: theme,
            ageGroup: ageGroup.rawValue,
            pageCount: pageCount,
            focusTags: request.focusTags?.map { $0.rawValue } ?? [],
            customFocus: request.customFocus,
            aiGenerated: request.aiGenerated,
            storyOutline: mockOutline,
            pageTexts: mockPages.map { $0.text },
            characterDescriptions: mockCharacters,
            artStyle: "children_book",
            status: "completed",
            tokensCost: pageCount * 2, // Mock token cost
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    /// Generate mock title based on theme and story type
    private func generateMockTitle(theme: String, storyType: StoryType) -> String {
        let themeWords = theme.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .prefix(3)
            .joined(separator: " ")

        switch storyType {
        case .bedtimeStory:
            return "The Sleepy \(themeWords.capitalized) Adventure"
        case .adventureStory:
            return "The Great \(themeWords.capitalized) Quest"
        case .educationalStory:
            return "Learning About \(themeWords.capitalized)"
        case .friendshipStory:
            return "Friends and \(themeWords.capitalized)"
        case .fantasyStory:
            return "The Magical \(themeWords.capitalized)"
        case .coloringBook:
            return "The Colorful World of \(themeWords.capitalized)"
        }
    }

    /// Generate mock story pages
    private func generateMockPages(theme: String, storyType: StoryType, pageCount: Int) -> [StoryPage] {
        var pages: [StoryPage] = []

        for i in 1...pageCount {
            let pageTitle: String
            let pageText: String
            let sceneDescription: String
            let characters = ["Emma", "Forest Friends"]

            switch i {
            case 1:
                pageTitle = "The Beginning"
                pageText = "Once upon a time, in a magical place where \(theme) comes to life, there lived a curious little girl named Emma. She loved to explore and discover new things every day."
                sceneDescription = "Emma standing at the edge of a magical forest with sparkling lights and friendly creatures peeking out from behind trees"

            case 2:
                pageTitle = "The Discovery"
                pageText = "One bright morning, Emma discovered something wonderful hidden in her backyard. It was exactly what she had been dreaming about - \(theme) right before her eyes!"
                sceneDescription = "Emma pointing excitedly at magical elements related to \(theme), with her eyes wide with wonder and joy"

            case pageCount:
                pageTitle = "The Happy Ending"
                pageText = "Emma learned so much on her adventure with \(theme). She realized that the best discoveries come when you're brave enough to explore and kind enough to share with friends."
                sceneDescription = "Emma surrounded by friends, all smiling and celebrating their adventure together under a beautiful sunset"

            default:
                pageTitle = "The Adventure Continues"
                pageText = "Emma's journey through the world of \(theme) taught her something new. She met wonderful friends who showed her the magic that happens when you believe in yourself."
                sceneDescription = "Emma having fun with magical creatures and friends, exploring the wonderful world of \(theme)"
            }

            let page = StoryPage(
                pageNumber: i,
                title: pageTitle,
                text: pageText,
                sceneDescription: sceneDescription,
                characters: characters
            )

            pages.append(page)
        }

        return pages
    }

    /// Generate mock character descriptions
    private func generateMockCharacters(theme: String) -> [String: CharacterDescription] {
        // Since we're using real API now, return empty dictionary for mock data
        // CharacterDescription has a custom decoder that expects backend format
        return [:]
    }
}