import Foundation
import Combine

@MainActor
class BedtimeStoriesService: ObservableObject {
    static let shared = BedtimeStoriesService()

    @Published var config: BedtimeStoriesConfig?
    @Published var themes: [BedtimeThemeOption] = []
    @Published var category: BedtimeStoryCategory?
    @Published var stories: [BedtimeStory] = []
    @Published var currentDraft: BedtimeDraft?
    @Published var error: String?

    private let baseURL = AppConfig.API.baseURL

    private init() {}

    // MARK: - 1. Load Configuration (Auth Required)

    func loadConfig() async throws -> BedtimeStoriesConfig {
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw BedtimeStoryError.noToken
        }

        let url = URL(string: "\(baseURL)/bedtime-stories/config")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Add profile ID if available
        if let profileId = ProfileService.shared.currentProfile?.id {
            request.setValue(profileId, forHTTPHeaderField: "X-Profile-ID")
        }

        #if DEBUG
        print("📖 BedtimeStoriesService: Loading config from \(url)")
        print("   - Token: \(token.prefix(20))...")
        print("   - Profile ID: \(ProfileService.shared.currentProfile?.id ?? "none")")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BedtimeStoryError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw BedtimeStoryError.apiError(apiError.userMessage)
            }
            throw BedtimeStoryError.httpError(httpResponse.statusCode)
        }

        let config = try JSONDecoder().decode(BedtimeStoriesConfig.self, from: data)

        #if DEBUG
        print("✅ BedtimeStoriesService: Config loaded")
        print("   - Voices: \(config.voices.count)")
        print("   - Speed options: \(config.speedOptions.count)")
        print("   - Defaults: voice=\(config.defaults.voiceId), speed=\(config.defaults.speed)")
        #endif

        await MainActor.run {
            self.config = config
        }

        return config
    }

    // MARK: - 2. Get Themes

    func getThemes() async throws -> BedtimeThemesResponse {
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw BedtimeStoryError.noToken
        }

        let url = URL(string: "\(baseURL)/bedtime-stories/themes")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Add profile ID if available
        if let profileId = ProfileService.shared.currentProfile?.id {
            request.setValue(profileId, forHTTPHeaderField: "X-Profile-ID")
        }

        #if DEBUG
        print("📖 BedtimeStoriesService: Loading themes from \(url)")
        print("   - Token: \(token.prefix(20))...")
        print("   - Profile ID: \(ProfileService.shared.currentProfile?.id ?? "none")")
        print("   - Headers: \(request.allHTTPHeaderFields ?? [:])")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BedtimeStoryError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            #if DEBUG
            print("❌ BedtimeStoriesService getThemes: HTTP Error \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("   - Response: \(responseString)")
            }
            #endif

            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw BedtimeStoryError.apiError(apiError.userMessage)
            }
            throw BedtimeStoryError.httpError(httpResponse.statusCode)
        }

        let themesResponse = try JSONDecoder().decode(BedtimeThemesResponse.self, from: data)

        #if DEBUG
        print("✅ BedtimeStoriesService: Loaded \(themesResponse.themes.count) themes")
        #endif

        await MainActor.run {
            self.themes = themesResponse.themes
            self.category = themesResponse.category
        }

        return themesResponse
    }

    // MARK: - 3. Create Draft (FREE - No Tokens)

    func createDraft(
        prompt: String,
        length: BedtimeStoryLength,
        optionId: String,
        characterName: String? = nil,
        ageGroup: String? = nil
    ) async throws -> BedtimeDraft {
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw BedtimeStoryError.noToken
        }

        let url = URL(string: "\(baseURL)/bedtime-stories/draft")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Add profile ID if available
        if let profileId = ProfileService.shared.currentProfile?.id {
            request.setValue(profileId, forHTTPHeaderField: "X-Profile-ID")
        }

        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = CreateBedtimeDraftRequest(
            prompt: prompt,
            length: length,
            optionId: optionId,
            characterName: characterName,
            ageGroup: ageGroup
        )
        request.httpBody = try JSONEncoder().encode(body)

        #if DEBUG
        print("📖 BedtimeStoriesService: Creating draft")
        print("   - Prompt: \(prompt)")
        print("   - Length: \(length.rawValue) (\(length.tokenCost) tokens)")
        print("   - Theme: \(optionId)")
        print("   - Token: \(token.prefix(20))...")
        print("   - Profile ID: \(ProfileService.shared.currentProfile?.id ?? "none")")
        print("   - Headers: \(request.allHTTPHeaderFields ?? [:])")
        if let bodyData = request.httpBody, let bodyString = String(data: bodyData, encoding: .utf8) {
            print("   - Request Body: \(bodyString)")
        }
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BedtimeStoryError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            #if DEBUG
            print("❌ BedtimeStoriesService createDraft: HTTP Error \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("   - Response: \(responseString)")
            }
            #endif

            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw BedtimeStoryError.apiError(apiError.userMessage)
            }
            throw BedtimeStoryError.httpError(httpResponse.statusCode)
        }

        let draftResponse = try JSONDecoder().decode(BedtimeDraftResponse.self, from: data)

        #if DEBUG
        print("✅ BedtimeStoriesService: Draft created - \(draftResponse.draft.title)")
        print("   - Word count: \(draftResponse.draft.wordCount)")
        print("   - Duration: \(draftResponse.draft.estimatedDuration)s")
        #endif

        await MainActor.run {
            self.currentDraft = draftResponse.draft
        }

        return draftResponse.draft
    }

    // MARK: - 4. Update Draft

    func updateDraft(id: String, storyText: String, title: String? = nil) async throws {
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw BedtimeStoryError.noToken
        }

        let url = URL(string: "\(baseURL)/bedtime-stories/draft/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add profile ID if available
        if let profileId = ProfileService.shared.currentProfile?.id {
            request.setValue(profileId, forHTTPHeaderField: "X-Profile-ID")
        }

        let body = UpdateBedtimeDraftRequest(storyText: storyText, title: title)
        request.httpBody = try JSONEncoder().encode(body)

        #if DEBUG
        print("📖 BedtimeStoriesService: Updating draft \(id)")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BedtimeStoryError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw BedtimeStoryError.apiError(apiError.userMessage)
            }
            throw BedtimeStoryError.httpError(httpResponse.statusCode)
        }

        #if DEBUG
        print("✅ BedtimeStoriesService: Draft updated successfully")
        #endif

        // Update local draft if it matches
        await MainActor.run {
            if currentDraft?.id == id {
                currentDraft?.storyText = storyText
                if let title = title {
                    currentDraft?.title = title
                }
            }
        }
    }

    // MARK: - 5. Generate Story (COSTS TOKENS)

    func generateStory(
        draftId: String,
        voiceId: String = "nova",
        speed: Double = 1.0
    ) async throws -> BedtimeStory {
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw BedtimeStoryError.noToken
        }

        let url = URL(string: "\(baseURL)/bedtime-stories/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add profile ID if available
        if let profileId = ProfileService.shared.currentProfile?.id {
            request.setValue(profileId, forHTTPHeaderField: "X-Profile-ID")
        }

        let body = GenerateBedtimeStoryRequest(draftId: draftId, voiceId: voiceId, speed: speed)
        request.httpBody = try JSONEncoder().encode(body)

        #if DEBUG
        print("📖 BedtimeStoriesService: Generating story from draft \(draftId)")
        print("   - Voice: \(voiceId)")
        print("   - Speed: \(speed)")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BedtimeStoryError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw BedtimeStoryError.apiError(apiError.userMessage)
            }
            throw BedtimeStoryError.httpError(httpResponse.statusCode)
        }

        let generateResponse = try JSONDecoder().decode(GenerateBedtimeStoryResponse.self, from: data)

        #if DEBUG
        print("✅ BedtimeStoriesService: Story generated successfully")
        print("   - Audio URL: \(generateResponse.story.audioUrl)")
        print("   - Image URL: \(generateResponse.story.imageUrl)")
        #endif

        return generateResponse.story
    }

    // MARK: - 6. Get Stories Library

    func getStories(
        page: Int = 1,
        limit: Int = 20,
        favorites: Bool? = nil,
        search: String? = nil,
        theme: String? = nil,
        filterByProfile: String? = nil,
        length: BedtimeStoryLength? = nil,
        status: String = "completed"
    ) async throws -> BedtimeStoriesResponse {
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw BedtimeStoryError.noToken
        }

        var components = URLComponents(string: "\(baseURL)/bedtime-stories")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "status", value: status)
        ]

        if let favorites = favorites {
            queryItems.append(URLQueryItem(name: "favorites", value: "\(favorites)"))
        }
        if let search = search {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        if let theme = theme {
            queryItems.append(URLQueryItem(name: "theme", value: theme))
        }
        if let filterByProfile = filterByProfile {
            queryItems.append(URLQueryItem(name: "filterByProfile", value: filterByProfile))
        }
        if let length = length {
            queryItems.append(URLQueryItem(name: "length", value: length.rawValue))
        }

        components.queryItems = queryItems

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Add profile ID if available
        if let profileId = ProfileService.shared.currentProfile?.id {
            request.setValue(profileId, forHTTPHeaderField: "X-Profile-ID")
        }

        #if DEBUG
        print("📖 BedtimeStoriesService: Loading stories - page \(page)")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BedtimeStoryError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw BedtimeStoryError.apiError(apiError.userMessage)
            }
            throw BedtimeStoryError.httpError(httpResponse.statusCode)
        }

        #if DEBUG
        print("📥 BedtimeStoriesService: Raw API Response:")
        if let responseString = String(data: data, encoding: .utf8) {
            print(responseString)
        }
        #endif

        let storiesResponse = try JSONDecoder().decode(BedtimeStoriesResponse.self, from: data)

        #if DEBUG
        print("✅ BedtimeStoriesService: Loaded \(storiesResponse.stories.count) stories (list view - no storyText/wordTimestamps)")
        for (index, story) in storiesResponse.stories.enumerated() {
            print("   Story \(index + 1): \(story.title)")
            print("      - ID: \(story.id)")
            print("      - Duration: \(story.duration)s")
            print("      - Theme: \(story.theme ?? "none")")
        }
        #endif

        await MainActor.run {
            self.stories = storiesResponse.stories
        }

        return storiesResponse
    }

    // MARK: - 7. Get Single Story

    func getStory(id: String) async throws -> BedtimeStory {
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw BedtimeStoryError.noToken
        }

        let url = URL(string: "\(baseURL)/bedtime-stories/\(id)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Add profile ID if available
        if let profileId = ProfileService.shared.currentProfile?.id {
            request.setValue(profileId, forHTTPHeaderField: "X-Profile-ID")
        }

        #if DEBUG
        print("📖 BedtimeStoriesService: Fetching single story from \(url)")
        print("   - Story ID: \(id)")
        print("   - Token: \(token.prefix(20))...")
        #endif

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BedtimeStoryError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            #if DEBUG
            print("❌ BedtimeStoriesService getStory: HTTP Error \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("   - Response: \(responseString)")
            }
            #endif

            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw BedtimeStoryError.apiError(apiError.userMessage)
            }
            throw BedtimeStoryError.httpError(httpResponse.statusCode)
        }

        #if DEBUG
        print("📥 BedtimeStoriesService getStory: Raw API Response:")
        if let responseString = String(data: data, encoding: .utf8) {
            print(responseString)
        }
        #endif

        let storyResponse = try JSONDecoder().decode(SingleBedtimeStoryResponse.self, from: data)

        #if DEBUG
        print("✅ BedtimeStoriesService: Single story loaded")
        print("   - Title: \(storyResponse.story.title)")
        print("   - Has storyText: \(storyResponse.story.storyText != nil)")
        if let storyText = storyResponse.story.storyText {
            print("   - StoryText length: \(storyText.count) chars")
            print("   - First 200 chars: \(String(storyText.prefix(200)))")
        }
        print("   - Has wordTimestamps: \(storyResponse.story.wordTimestamps != nil)")
        if let timestamps = storyResponse.story.wordTimestamps {
            print("   - WordTimestamps length: \(timestamps.count) chars")
            print("   - First 200 chars: \(String(timestamps.prefix(200)))")
        }
        #endif

        return storyResponse.story
    }

    // MARK: - 8. Toggle Favorite

    func toggleFavorite(id: String) async throws -> Bool {
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw BedtimeStoryError.noToken
        }

        let url = URL(string: "\(baseURL)/bedtime-stories/\(id)/favorite")!
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Add profile ID if available
        if let profileId = ProfileService.shared.currentProfile?.id {
            request.setValue(profileId, forHTTPHeaderField: "X-Profile-ID")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BedtimeStoryError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw BedtimeStoryError.apiError(apiError.userMessage)
            }
            throw BedtimeStoryError.httpError(httpResponse.statusCode)
        }

        let favoriteResponse = try JSONDecoder().decode(BedtimeFavoriteResponse.self, from: data)

        // Update local state
        await MainActor.run {
            if let index = stories.firstIndex(where: { $0.id == id }) {
                stories[index].isFavorite = favoriteResponse.isFavorite
            }
        }

        return favoriteResponse.isFavorite
    }

    // MARK: - 9. Delete Story

    func deleteStory(id: String) async throws {
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw BedtimeStoryError.noToken
        }

        let url = URL(string: "\(baseURL)/bedtime-stories/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Add profile ID if available
        if let profileId = ProfileService.shared.currentProfile?.id {
            request.setValue(profileId, forHTTPHeaderField: "X-Profile-ID")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BedtimeStoryError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw BedtimeStoryError.apiError(apiError.userMessage)
            }
            throw BedtimeStoryError.httpError(httpResponse.statusCode)
        }

        await MainActor.run {
            stories.removeAll { $0.id == id }
        }
    }
}

// MARK: - Error Types

enum BedtimeStoryError: LocalizedError {
    case noToken
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case insufficientTokens(required: Int, available: Int)

    var errorDescription: String? {
        switch self {
        case .noToken:
            return "Authentication token not found. Please sign in again."
        case .invalidResponse:
            return "Invalid server response. Please try again."
        case .httpError(let code):
            return "Server error (\(code)). Please try again."
        case .apiError(let message):
            return message
        case .insufficientTokens(let required, let available):
            return "Insufficient tokens. Need \(required), have \(available)."
        }
    }
}
