import Foundation
import Combine

class DraftService: ObservableObject {
    static let shared = DraftService()
    
    private let baseURL = AppConfig.API.baseURL
    @Published var drafts: [StoryDraft] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private init() {}
    
    // MARK: - Draft Creation
    
    /// Create a new story draft
    func createDraft(_ request: CreateDraftRequest) async throws -> CreateDraftResponse {
        let endpoint = "\(baseURL)/stories/drafts"
        
        guard let url = URL(string: endpoint) else {
            throw DraftError.invalidURL
        }
        
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw DraftError.noToken
        }
        
        print("📝 DraftService: Creating story draft")
        print("🔗 Request URL: \(endpoint)")
        print("📋 Theme: \(request.theme)")
        print("📋 Story Type: \(request.storyType.displayName)")
        print("📋 Age Group: \(request.ageGroup.displayName)")
        print("📋 Page Count: \(request.pageCount)")
        
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestData = try JSONEncoder().encode(request)
        httpRequest.httpBody = requestData
        
        #if DEBUG
        if let requestString = String(data: requestData, encoding: .utf8) {
            print("📤 Draft Request: \(requestString)")
        }
        #endif
        
        let (data, response) = try await URLSession.shared.data(for: httpRequest)
        
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
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
        
        let (data, response) = try await URLSession.shared.data(for: httpRequest)
        
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
        
        let (data, response) = try await URLSession.shared.data(for: httpRequest)
        
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
        
        let (data, response) = try await URLSession.shared.data(for: httpRequest)
        
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
        let endpoint = "\(baseURL)/books/\(draftId)/generate-images"
        
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
        
        // Add profile header if available (comment out for now to avoid ProfileService dependency)
        // if let profileService = try? ProfileService.shared,
        //    let currentProfile = profileService.currentProfile {
        //     httpRequest.setValue(currentProfile.id, forHTTPHeaderField: "X-Profile-ID")
        // }
        
        httpRequest.httpBody = try JSONEncoder().encode(options)
        
        let (data, response) = try await URLSession.shared.data(for: httpRequest)
        
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
        print("✅ DraftService: Successfully started book generation with ID: \(bookResponse.bookId)")
        
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
}