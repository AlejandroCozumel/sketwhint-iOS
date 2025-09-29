import Foundation
import Combine

@MainActor
class FolderService: ObservableObject {
    static let shared = FolderService()
    
    @Published var folders: [UserFolder] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let baseURL = AppConfig.API.baseURL
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Folder Management
    
    func loadFolders() async throws {
        isLoading = true
        defer { isLoading = false }
        
        print("🗂️ FolderService: Loading folders...")
        
        guard let url = URL(string: "\(baseURL)\(AppConfig.API.Endpoints.folders)") else {
            throw FolderError.invalidData
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add authentication
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw FolderError.profileSelectionRequired
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Add profile header if available
        if let currentProfile = ProfileService.shared.currentProfile {
            request.setValue(currentProfile.id, forHTTPHeaderField: "X-Profile-ID")
            print("🎯 FolderService: Using profile \(currentProfile.name) (ID: \(currentProfile.id))")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FolderError.networkError("Invalid response")
            }
            
            print("📡 FolderService: Response status \(httpResponse.statusCode)")
            
            guard 200...299 ~= httpResponse.statusCode else {
                if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                    throw FolderError.serverError(apiError.userMessage)
                } else {
                    throw FolderError.networkError("Failed to load folders")
                }
            }
            
            let foldersResponse = try JSONDecoder().decode(GetFoldersResponse.self, from: data)
            
            print("✅ FolderService: Loaded \(foldersResponse.folders.count) folders")
            for folder in foldersResponse.folders {
                print("  📁 \(folder.name) (\(folder.imageCount) images) - Created by: \(folder.createdBy.profileName ?? "Unknown")")
            }
            
            await MainActor.run {
                self.folders = foldersResponse.folders
                self.error = nil
            }
            
        } catch {
            print("❌ FolderService: Error loading folders - \(error)")
            await MainActor.run {
                self.error = error.localizedDescription
            }
            throw error
        }
    }
    
    func createFolder(name: String, description: String?, color: String, icon: String) async throws -> UserFolder {
        print("🗂️ FolderService: Creating folder '\(name)'...")
        
        guard let url = URL(string: "\(baseURL)\(AppConfig.API.Endpoints.folders)") else {
            throw FolderError.invalidData
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw FolderError.profileSelectionRequired
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Add profile header (required for creation)
        guard let currentProfile = ProfileService.shared.currentProfile else {
            throw FolderError.profileSelectionRequired
        }
        request.setValue(currentProfile.id, forHTTPHeaderField: "X-Profile-ID")
        
        let createRequest = CreateFolderRequest(
            name: name,
            description: description?.isEmpty == true ? nil : description,
            color: color,
            icon: icon
        )
        
        request.httpBody = try JSONEncoder().encode(createRequest)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FolderError.networkError("Invalid response")
            }
            
            print("📡 FolderService: Create response status \(httpResponse.statusCode)")
            
            guard 200...299 ~= httpResponse.statusCode else {
                if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                    throw FolderError.serverError(apiError.userMessage)
                } else {
                    throw FolderError.networkError("Failed to create folder")
                }
            }
            
            let createResponse = try JSONDecoder().decode(CreateFolderResponse.self, from: data)
            
            print("✅ FolderService: Created folder '\(createResponse.folder.name)' with ID: \(createResponse.folder.id)")
            
            await MainActor.run {
                self.folders.append(createResponse.folder)
                self.folders.sort { $0.sortOrder < $1.sortOrder }
            }
            
            return createResponse.folder
            
        } catch {
            print("❌ FolderService: Error creating folder - \(error)")
            throw error
        }
    }
    
    func updateFolder(_ folder: UserFolder, name: String?, description: String?, color: String?, icon: String?) async throws -> UserFolder {
        print("🗂️ FolderService: Updating folder '\(folder.name)'...")
        
        guard let url = URL(string: "\(baseURL)/folders/\(folder.id)") else {
            throw FolderError.invalidData
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw FolderError.profileSelectionRequired
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let updateRequest = UpdateFolderRequest(
            name: name,
            description: description?.isEmpty == true ? nil : description,
            color: color,
            icon: icon
        )
        
        request.httpBody = try JSONEncoder().encode(updateRequest)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FolderError.networkError("Invalid response")
            }
            
            print("📡 FolderService: Update response status \(httpResponse.statusCode)")
            
            guard 200...299 ~= httpResponse.statusCode else {
                if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                    throw FolderError.serverError(apiError.userMessage)
                } else {
                    throw FolderError.networkError("Failed to update folder")
                }
            }
            
            let updateResponse = try JSONDecoder().decode(UpdateFolderResponse.self, from: data)
            
            print("✅ FolderService: Updated folder '\(updateResponse.folder.name)'")
            
            await MainActor.run {
                if let index = self.folders.firstIndex(where: { $0.id == folder.id }) {
                    self.folders[index] = updateResponse.folder
                }
            }
            
            return updateResponse.folder
            
        } catch {
            print("❌ FolderService: Error updating folder - \(error)")
            throw error
        }
    }
    
    func deleteFolder(_ folder: UserFolder) async throws {
        print("🗂️ FolderService: Deleting folder '\(folder.name)'...")
        
        guard let url = URL(string: "\(baseURL)/folders/\(folder.id)") else {
            throw FolderError.invalidData
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        // Add authentication
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw FolderError.profileSelectionRequired
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FolderError.networkError("Invalid response")
            }
            
            print("📡 FolderService: Delete response status \(httpResponse.statusCode)")
            
            guard 200...299 ~= httpResponse.statusCode else {
                if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                    throw FolderError.serverError(apiError.userMessage)
                } else {
                    throw FolderError.networkError("Failed to delete folder")
                }
            }
            
            print("✅ FolderService: Deleted folder '\(folder.name)'")
            
            await MainActor.run {
                self.folders.removeAll { $0.id == folder.id }
            }
            
        } catch {
            print("❌ FolderService: Error deleting folder - \(error)")
            throw error
        }
    }
    
    // MARK: - Folder Images Management
    
    func getFolderImages(
        folderId: String, 
        page: Int = 1, 
        limit: Int = 20,
        favorites: Bool? = nil,
        category: String? = nil,
        search: String? = nil,
        filterByProfile: String? = nil
    ) async throws -> FolderImagesResponse {
        print("🗂️ FolderService: Loading images for folder \(folderId)...")
        print("🔍 FolderService: Filters - favorites: \(favorites?.description ?? "nil"), category: \(category ?? "nil"), search: \(search ?? "nil"), profile: \(filterByProfile ?? "nil")")
        
        // Build query parameters (same as gallery)
        var queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        
        if let favorites = favorites {
            queryItems.append(URLQueryItem(name: "favorites", value: "\(favorites)"))
        }
        
        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        
        if let search = search {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        
        if let filterByProfile = filterByProfile {
            queryItems.append(URLQueryItem(name: "filterByProfile", value: filterByProfile))
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/folders/\(folderId)/images")!
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw FolderError.invalidData
        }
        
        // Use APIRequestHelper to automatically include X-Profile-ID header for profile-aware content
        let request = try APIRequestHelper.shared.createGETRequest(
            url: url,
            includeProfileHeader: true
        )
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FolderError.networkError("Invalid response")
            }
            
            print("📡 FolderService: Folder images response status \(httpResponse.statusCode)")
            
            guard 200...299 ~= httpResponse.statusCode else {
                #if DEBUG
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ FolderService: Error response body: \(responseString)")
                }
                #endif
                
                if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                    throw FolderError.serverError(apiError.userMessage)
                } else {
                    throw FolderError.networkError("Failed to load folder images (HTTP \(httpResponse.statusCode))")
                }
            }
            
            #if DEBUG
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 FolderService: Success response: \(responseString)")
            }
            #endif
            
            let imagesResponse = try JSONDecoder().decode(FolderImagesResponse.self, from: data)
            
            print("✅ FolderService: Loaded \(imagesResponse.images.count) images for folder ID '\(folderId)' (total: \(imagesResponse.total))")
            
            // Empty results are valid - don't treat as error
            if imagesResponse.images.isEmpty {
                print("ℹ️ FolderService: Folder has no images for current profile/filters")
            }
            
            return imagesResponse
            
        } catch {
            print("❌ FolderService: Error loading folder images - \(error)")
            
            // Provide more specific error information
            if error is DecodingError {
                print("💥 JSON Decoding Error - API response structure mismatch")
            } else {
                print("🌐 Network or other error")
            }
            
            throw error
        }
    }
    
    func moveImagesToFolder(folderId: String, imageIds: [String], notes: String? = nil) async throws -> MoveImagesToFolderResponse {
        print("🗂️ FolderService: Moving \(imageIds.count) images to folder \(folderId)...")
        
        guard let url = URL(string: "\(baseURL)/folders/\(folderId)/move-images") else {
            throw FolderError.invalidData
        }
        
        let moveRequest = MoveImagesToFolderRequest(
            imageIds: imageIds,
            notes: notes?.isEmpty == true ? nil : notes
        )
        
        // Use APIRequestHelper to automatically include X-Profile-ID header for profile-aware operations
        let request = try APIRequestHelper.shared.createJSONRequest(
            url: url,
            method: "POST",
            body: moveRequest,
            includeProfileHeader: true
        )
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FolderError.networkError("Invalid response")
            }
            
            print("📡 FolderService: Move images response status \(httpResponse.statusCode)")
            
            guard 200...299 ~= httpResponse.statusCode else {
                if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                    throw FolderError.serverError(apiError.userMessage)
                } else {
                    throw FolderError.networkError("Failed to move images")
                }
            }
            
            let moveResponse = try JSONDecoder().decode(MoveImagesToFolderResponse.self, from: data)
            
            print("✅ FolderService: \(moveResponse.message) - Moved: \(moveResponse.moved), Skipped: \(moveResponse.skipped)")
            
            // Refresh folders to update image counts
            Task {
                try await loadFolders()
            }
            
            return moveResponse
            
        } catch {
            print("❌ FolderService: Error moving images - \(error)")
            throw error
        }
    }
    
    func removeImagesFromFolder(folderId: String, imageIds: [String]) async throws -> RemoveImagesFromFolderResponse {
        print("🗂️ FolderService: Removing \(imageIds.count) images from folder \(folderId)...")
        
        guard let url = URL(string: "\(baseURL)/folders/\(folderId)/remove-images") else {
            throw FolderError.invalidData
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw FolderError.profileSelectionRequired
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let removeRequest = RemoveImagesFromFolderRequest(imageIds: imageIds)
        request.httpBody = try JSONEncoder().encode(removeRequest)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FolderError.networkError("Invalid response")
            }
            
            print("📡 FolderService: Remove images response status \(httpResponse.statusCode)")
            
            guard 200...299 ~= httpResponse.statusCode else {
                if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                    throw FolderError.serverError(apiError.userMessage)
                } else {
                    throw FolderError.networkError("Failed to remove images")
                }
            }
            
            let removeResponse = try JSONDecoder().decode(RemoveImagesFromFolderResponse.self, from: data)
            
            print("✅ FolderService: \(removeResponse.message) - Removed: \(removeResponse.removed)")
            
            // Refresh folders to update image counts
            Task {
                try await loadFolders()
            }
            
            return removeResponse
            
        } catch {
            print("❌ FolderService: Error removing images - \(error)")
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    func getFolderById(_ id: String) -> UserFolder? {
        return folders.first { $0.id == id }
    }
    
    func getFoldersByCreator(_ profileId: String) -> [UserFolder] {
        return folders.filter { $0.createdBy.profileId == profileId }
    }
    
    func clearFolders() {
        folders.removeAll()
        error = nil
    }
}