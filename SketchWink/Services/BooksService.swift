import Foundation
import Combine

@MainActor
class BooksService: ObservableObject {
    static let shared = BooksService()

    @Published var books: [StoryBook] = []
    @Published var themes: [BookThemeOption] = []
    @Published var category: BookCategory?
    @Published var focusTags: [BookFocusTag] = []
    @Published var isLoading = false
    @Published var error: String?

    private let baseURL = AppConfig.API.baseURL
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupGlobalListeners()
    }
    
    private func setupGlobalListeners() {
        // Listen for all progress events from the global stream
        GlobalSSEService.shared.observe(event: "progress") { [weak self] event in
            guard let self = self else { return }
            
            // We only care about completion notifications here
            // Parse the event data
            let dataString = event.data
            guard let data = dataString.data(using: .utf8) else { return }
            
            // Simple parsing to check status without full decoding overhead if possible
            // OR use the existing GenerationProgressData struct if available
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String,
                   status == "completed" {
                    
                    #if DEBUG
                    print("📚 BooksService: Received 'completed' status, refreshing books...")
                    #endif
                    
                    Task { @MainActor [weak self] in
                        // Refresh the books list to show the new book
                        await self?.refreshBooks()
                    }
                }
            } catch {
                #if DEBUG
                print("📚 BooksService: Failed to parse event data: \(error)")
                #endif
            }
        }
    }
    
    // MARK: - Books Management
    
    /// Get all story books with pagination and filtering
    func getBooks(
        page: Int = 1,
        limit: Int = 20,
        favorites: Bool? = nil,
        sortBy: String = "createdAt",
        sortOrder: String = "desc",
        filterByProfile: String? = nil,
        category: String? = nil
    ) async throws -> BooksResponse {
        let endpoint = "\(baseURL)\(AppConfig.API.Endpoints.books)"
        
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
        
        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw BooksError.invalidURL
        }
        
        #if DEBUG
        print("📚 BooksService: Loading books")
        print("📤 URL: \(url.absoluteString)")
        print("🔍 Filters - Favorites: \(favorites?.description ?? "none"), Profile: \(filterByProfile ?? "none"), Category: \(category ?? "none")")
        #endif
        
        // Use APIRequestHelper to automatically include X-Profile-ID header for content filtering
        let request = try APIRequestHelper.shared.createGETRequest(
            url: url,
            includeProfileHeader: true
        )
        
        let (data, response) = try await APIRequestHelper.shared.performRequest(request)
        
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
        
        let booksResponse = try JSONDecoder().decode(BooksResponse.self, from: data)
        
        #if DEBUG
        print("✅ BooksService: Successfully decoded \(booksResponse.books.count) books")
        for book in booksResponse.books.prefix(3) {
            print("   - \(book.title) (isFavorite: \(book.isFavorite), inFolder: \(book.inFolder))")
        }
        #endif
        
        return booksResponse
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
    
    /// Refresh books list (reload first page)
    func refreshBooks() async {
        await loadBooks(page: 1)
    }
    
    /// Get book pages for reading experience
    func getBookPages(bookId: String) async throws -> BookWithPages {
        let endpoint = "\(baseURL)\(String(format: AppConfig.API.Endpoints.bookPages, bookId))"
        
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
        
        let (data, response) = try await APIRequestHelper.shared.performRequest(request)
        
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
        let endpoint = "\(baseURL)\(String(format: AppConfig.API.Endpoints.bookFavorite, bookId))"
        
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
        
        let (_, response) = try await APIRequestHelper.shared.performRequest(request)
        
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
        let endpoint = "\(baseURL)\(String(format: AppConfig.API.Endpoints.moveBookToFolder, bookId))"

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

        let (data, response) = try await APIRequestHelper.shared.performRequest(request)

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

    /// Delete a book
    func deleteBook(bookId: String) async throws {
        let endpoint = "\(baseURL)\(String(format: AppConfig.API.Endpoints.deleteBook, bookId))"

        guard let url = URL(string: endpoint) else {
            throw BooksError.invalidURL
        }

        #if DEBUG
        print("🗑️ BooksService: Deleting book \(bookId)")
        #endif

        let request = try APIRequestHelper.shared.createRequest(
            url: url,
            method: "DELETE",
            includeProfileHeader: true
        )

        let (data, response) = try await APIRequestHelper.shared.performRequest(request)

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

        // Update local state
        books.removeAll { $0.id == bookId }

        #if DEBUG
        print("✅ BooksService: Successfully deleted book \(bookId)")
        #endif
    }

    // MARK: - Themes & Focus Tags (Dynamic from Backend)

    /// Get book themes with translations based on user's preferred language
    func getThemes() async throws -> BookThemesResponse {
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw BooksError.invalidURL
        }

        let url = URL(string: "\(baseURL)/books/themes")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Add profile ID if available
        if let profileId = ProfileService.shared.currentProfile?.id {
            request.setValue(profileId, forHTTPHeaderField: "X-Profile-ID")
        }

        #if DEBUG
        print("📚 BooksService: Loading themes from \(url)")
        print("   - Token: \(token.prefix(20))...")
        print("   - Profile ID: \(ProfileService.shared.currentProfile?.id ?? "none")")
        print("   - Headers: \(request.allHTTPHeaderFields ?? [:])")
        #endif

        let (data, response) = try await APIRequestHelper.shared.performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BooksError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            #if DEBUG
            print("❌ BooksService getThemes: HTTP Error \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("   - Response: \(responseString)")
            }
            #endif

            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw BooksError.serverError(apiError.userMessage)
            }
            throw BooksError.httpError(httpResponse.statusCode)
        }

        let themesResponse = try JSONDecoder().decode(BookThemesResponse.self, from: data)

        #if DEBUG
        print("✅ BooksService: Loaded \(themesResponse.themes.count) themes")
        for theme in themesResponse.themes.prefix(3) {
            print("   - \(theme.name) (id: \(theme.id))")
        }
        #endif

        // Update published properties
        self.themes = themesResponse.themes
        self.category = themesResponse.category

        return themesResponse
    }

    /// Get book focus tags with translations based on user's preferred language
    func getFocusTags() async throws -> BookFocusTagsResponse {
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw BooksError.invalidURL
        }

        let url = URL(string: "\(baseURL)/books/focus-tags")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Add profile ID if available
        if let profileId = ProfileService.shared.currentProfile?.id {
            request.setValue(profileId, forHTTPHeaderField: "X-Profile-ID")
        }

        #if DEBUG
        print("📚 BooksService: Loading focus tags from \(url)")
        print("   - Token: \(token.prefix(20))...")
        print("   - Profile ID: \(ProfileService.shared.currentProfile?.id ?? "none")")
        #endif

        let (data, response) = try await APIRequestHelper.shared.performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BooksError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            #if DEBUG
            print("❌ BooksService getFocusTags: HTTP Error \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("   - Response: \(responseString)")
            }
            #endif

            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw BooksError.serverError(apiError.userMessage)
            }
            throw BooksError.httpError(httpResponse.statusCode)
        }

        let focusTagsResponse = try JSONDecoder().decode(BookFocusTagsResponse.self, from: data)

        #if DEBUG
        print("✅ BooksService: Loaded \(focusTagsResponse.focusTags.count) focus tags")
        for tag in focusTagsResponse.focusTags.prefix(3) {
            print("   - \(tag.name) (id: \(tag.id), icon: \(tag.icon))")
        }
        #endif

        // Update published property
        self.focusTags = focusTagsResponse.focusTags

        return focusTagsResponse
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