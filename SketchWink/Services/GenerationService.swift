import Foundation
import Combine

class GenerationService: ObservableObject {
    static let shared = GenerationService()
    
    private let baseURL = AppConfig.API.baseURL
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Categories and Options
    func getCategoriesWithOptions() async throws -> [CategoryWithOptions] {
        let endpoint = "\(baseURL)\(AppConfig.API.Endpoints.categories)"
        
        guard let url = URL(string: endpoint) else {
            throw GenerationError.invalidURL
        }
        
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw GenerationError.noToken
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenerationError.invalidResponse
        }
        
        // Debug logging
        #if DEBUG
        print("🌐 Categories API Response Status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Categories API Response: \(responseString)")
        }
        #endif
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw GenerationError.httpError(httpResponse.statusCode)
        }
        
        do {
            // Decode the wrapper response that matches your API structure
            let categoriesResponse = try JSONDecoder().decode(CategoriesResponse.self, from: data)
            
            // Convert to the format our UI expects
            return categoriesResponse.categories.map { $0.toCategoryWithOptions() }
        } catch {
            #if DEBUG
            print("❌ Categories Decoding Error: \(error)")
            #endif
            throw GenerationError.decodingError
        }
    }
    
    // MARK: - Prompt Enhancement Settings
    func getPromptEnhancementSettings() async throws -> PromptEnhancementSettings {
        let endpoint = "\(baseURL)\(AppConfig.API.Endpoints.promptEnhancementSettings)"
        
        guard let url = URL(string: endpoint) else {
            throw GenerationError.invalidURL
        }
        
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw GenerationError.noToken
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenerationError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw GenerationError.httpError(httpResponse.statusCode)
        }
        
        // GET endpoint returns direct format: {"promptEnhancementEnabled": true}
        return try JSONDecoder().decode(PromptEnhancementSettings.self, from: data)
    }
    
    func updatePromptEnhancementSettings(enabled: Bool) async throws -> (settings: PromptEnhancementSettings, message: String) {
        let endpoint = "\(baseURL)\(AppConfig.API.Endpoints.promptEnhancementSettings)"
        
        guard let url = URL(string: endpoint) else {
            throw GenerationError.invalidURL
        }
        
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw GenerationError.noToken
        }
        
        let requestBody = PromptEnhancementSettings(promptEnhancementEnabled: enabled)
        let jsonData = try JSONEncoder().encode(requestBody)
        
        #if DEBUG
        if let requestString = String(data: jsonData, encoding: .utf8) {
            print("🌐 PUT \(endpoint)")
            print("📤 Request Body: \(requestString)")
        }
        #endif
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        #if DEBUG
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Response: \(responseString)")
        }
        #endif
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenerationError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw GenerationError.httpError(httpResponse.statusCode)
        }
        
        // PUT endpoint returns wrapper format: {"message": "...", "settings": {...}}
        let decodedResponse = try JSONDecoder().decode(PromptEnhancementResponse.self, from: data)
        return (settings: decodedResponse.settings, message: decodedResponse.message)
    }
    
    // MARK: - Generation
    func createGeneration(_ request: CreateGenerationRequest) async throws -> Generation {
        let endpoint = "\(baseURL)\(AppConfig.API.Endpoints.generations)"
        
        guard let url = URL(string: endpoint) else {
            throw GenerationError.invalidURL
        }
        
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw GenerationError.noToken
        }
        
        let jsonData = try JSONEncoder().encode(request)
        
        #if DEBUG
        if let requestString = String(data: jsonData, encoding: .utf8) {
            print("🌐 POST \(endpoint)")
            print("📤 Generation Request: \(requestString)")
        }
        #endif
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        #if DEBUG
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Generation Response: \(responseString)")
        }
        #endif
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenerationError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw GenerationError.httpError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(Generation.self, from: data)
    }
    
    func getGeneration(id: String) async throws -> Generation {
        let endpoint = "\(baseURL)\(AppConfig.API.Endpoints.generations)/\(id)"
        
        guard let url = URL(string: endpoint) else {
            throw GenerationError.invalidURL
        }
        
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw GenerationError.noToken
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        #if DEBUG
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 GET Generation Response: \(responseString)")
        }
        #endif
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenerationError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw GenerationError.httpError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(Generation.self, from: data)
    }
    
    // MARK: - Gallery/Images
    func getUserImages(page: Int = 1, limit: Int = 20) async throws -> ImagesResponse {
        let endpoint = "\(baseURL)\(AppConfig.API.Endpoints.images)"
        
        var components = URLComponents(string: endpoint)!
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "sortBy", value: "createdAt"),
            URLQueryItem(name: "sortOrder", value: "desc")
        ]
        
        guard let url = components.url else {
            throw GenerationError.invalidURL
        }
        
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw GenerationError.noToken
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        #if DEBUG
        print("🌐 GET \(url.absoluteString)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Gallery Response: \(responseString)")
        }
        #endif
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenerationError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw GenerationError.httpError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(ImagesResponse.self, from: data)
    }
    
    func toggleImageFavorite(imageId: String) async throws {
        let endpoint = "\(baseURL)\(String(format: AppConfig.API.Endpoints.toggleFavorite, imageId))"
        
        guard let url = URL(string: endpoint) else {
            throw GenerationError.invalidURL
        }
        
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw GenerationError.noToken
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GenerationError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw GenerationError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Polling Helper
    func pollGenerationUntilComplete(id: String, maxAttempts: Int = 60) async throws -> Generation {
        for attempt in 1...maxAttempts {
            let generation = try await getGeneration(id: id)
            
            switch generation.status {
            case "completed":
                return generation
            case "failed":
                throw GenerationError.generationFailed(generation.errorMessage ?? "Generation failed")
            case "processing":
                // Wait 2 seconds before next poll
                try await Task.sleep(nanoseconds: 2_000_000_000)
                continue
            default:
                throw GenerationError.unknownStatus(generation.status)
            }
        }
        
        throw GenerationError.timeout
    }
}

// MARK: - Custom Errors
enum GenerationError: LocalizedError {
    case invalidURL
    case noToken
    case authenticationFailed
    case invalidResponse
    case httpError(Int)
    case decodingError
    case generationFailed(String)
    case unknownStatus(String)
    case timeout
    case upgradeRequired(feature: String, plan: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noToken:
            return "Authentication token not found"
        case .authenticationFailed:
            return "Authentication failed"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "Server error: \(code)"
        case .decodingError:
            return "Failed to decode response"
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        case .unknownStatus(let status):
            return "Unknown generation status: \(status)"
        case .timeout:
            return "Generation timed out"
        case .upgradeRequired(let feature, let plan):
            return "\(feature) requires \(plan) subscription. Upgrade to unlock this feature!"
        }
    }
}