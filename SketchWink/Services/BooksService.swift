import Foundation
import Combine

@MainActor
class BooksService: ObservableObject {
    static let shared = BooksService()
    
    @Published var books: [StoryBook] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let baseURL = AppConfig.API.baseURL
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Books Management
    
    /// Get all story books with pagination and filtering
    func getBooks(
        page: Int = 1,
        limit: Int = 20,
        favorites: Bool? = nil,
        sortBy: String = "createdAt",
        sortOrder: String = "desc",
        filterByProfile: String? = nil
    ) async throws -> BooksResponse {
        let endpoint = "\(baseURL)/books"
        
        var components = URLComponents(string: endpoint)!
        var queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "sortBy", value: sortBy),
            URLQueryItem(name: "sortOrder", value: sortOrder)
        ]
        
        // Add filtering parameters
        if let favorites = favorites {
            queryItems.append(URLQueryItem(name: "favorites", value: favorites ? "true" : "false"))
        }
        
        if let filterByProfile = filterByProfile {
            queryItems.append(URLQueryItem(name: "filterByProfile", value: filterByProfile))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw BooksError.invalidURL
        }
        
        #if DEBUG
        print("📚 BooksService: Loading books")
        print("📤 URL: \(url.absoluteString)")
        print("🔍 Filters - Favorites: \(favorites?.description ?? "none"), Profile: \(filterByProfile ?? "none")")
        #endif
        
        // Use APIRequestHelper to automatically include X-Profile-ID header for content filtering
        let request = try APIRequestHelper.shared.createGETRequest(
            url: url,
            includeProfileHeader: true
        )
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        #if DEBUG
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Books Response: \(responseString)")
        }
        #endif
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BooksError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            // Try to decode error message from API, fallback to generic error
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw BooksError.serverError(apiError.userMessage)
            } else {
                throw BooksError.httpError(httpResponse.statusCode)
            }
        }
        
        return try JSONDecoder().decode(BooksResponse.self, from: data)
    }
    
    /// Load books into published property
    func loadBooks(
        page: Int = 1,
        favorites: Bool? = nil,
        filterByProfile: String? = nil
    ) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await getBooks(
                page: page,
                favorites: favorites,
                filterByProfile: filterByProfile
            )
            
            if page == 1 {
                books = response.books
            } else {
                books.append(contentsOf: response.books)
            }
            
            error = nil
            
            #if DEBUG
            print("✅ BooksService: Loaded \(response.books.count) books (total: \(response.total))")
            #endif
            
        } catch {
            self.error = error.localizedDescription
            
            #if DEBUG
            print("❌ BooksService: Error loading books - \(error)")
            #endif
        }
    }
    
    /// Get book pages for reading experience
    func getBookPages(bookId: String) async throws -> BookWithPages {
        let endpoint = "\(baseURL)/books/\(bookId)/pages"
        
        guard let url = URL(string: endpoint) else {
            throw BooksError.invalidURL
        }
        
        #if DEBUG
        print("📚 BooksService: Loading pages for book \(bookId)")
        #endif
        
        let request = try APIRequestHelper.shared.createGETRequest(
            url: url,
            includeProfileHeader: true
        )
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        #if DEBUG
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Book Pages Response: \(responseString)")
        }
        #endif
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BooksError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw BooksError.serverError(apiError.userMessage)
            } else {
                throw BooksError.httpError(httpResponse.statusCode)
            }
        }
        
        return try JSONDecoder().decode(BookWithPages.self, from: data)
    }
    
    /// Toggle book favorite status
    func toggleBookFavorite(bookId: String) async throws {
        let endpoint = "\(baseURL)/books/\(bookId)/favorite"
        
        guard let url = URL(string: endpoint) else {
            throw BooksError.invalidURL
        }
        
        #if DEBUG
        print("❤️ BooksService: Toggling favorite for book \(bookId)")
        #endif
        
        let request = try APIRequestHelper.shared.createRequest(
            url: url,
            method: "PATCH",
            includeProfileHeader: true
        )
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BooksError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw BooksError.httpError(httpResponse.statusCode)
        }
        
        // Update local state
        if let index = books.firstIndex(where: { $0.id == bookId }) {
            books[index].isFavorite.toggle()
        }
        
        #if DEBUG
        print("✅ BooksService: Toggled favorite for book \(bookId)")
        #endif
    }
    
    /// Move book to folder
    func moveBookToFolder(bookId: String, folderId: String, notes: String? = nil) async throws -> MoveBookToFolderResponse {
        let endpoint = "\(baseURL)/books/\(bookId)/move-to-folder"
        
        guard let url = URL(string: endpoint) else {
            throw BooksError.invalidURL
        }
        
        let moveRequest = MoveBookToFolderRequest(
            folderId: folderId,
            notes: notes?.isEmpty == true ? nil : notes
        )
        
        #if DEBUG
        print("📁 BooksService: Moving book \(bookId) to folder \(folderId)")
        #endif
        
        let request = try APIRequestHelper.shared.createJSONRequest(
            url: url,
            method: "POST",
            body: moveRequest,
            includeProfileHeader: true
        )
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BooksError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw BooksError.serverError(apiError.userMessage)
            } else {
                throw BooksError.httpError(httpResponse.statusCode)
            }
        }
        
        let moveResponse = try JSONDecoder().decode(MoveBookToFolderResponse.self, from: data)
        
        #if DEBUG
        print("✅ BooksService: \(moveResponse.message)")
        #endif
        
        return moveResponse
    }
    
    // MARK: - Helper Methods
    
    func clearBooks() {
        books.removeAll()
        error = nil
    }
    
    func getBookById(_ id: String) -> StoryBook? {
        return books.first { $0.id == id }
    }
    
    func getFavoriteBooks() -> [StoryBook] {
        return books.filter { $0.isFavorite }
    }
}

// MARK: - Books Error Types

enum BooksError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serverError(String)
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "Server error: \(code)"
        case .serverError(let message):
            return message
        case .decodingError:
            return "Failed to decode response"
        }
    }
}