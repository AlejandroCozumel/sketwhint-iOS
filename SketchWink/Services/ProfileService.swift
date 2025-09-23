import Foundation
import Combine

// MARK: - Profile Service
class ProfileService: ObservableObject {
    static let shared = ProfileService()
    private init() {}
    
    @Published var hasSelectedProfile = false
    @Published var currentProfile: FamilyProfile?
    @Published var availableProfiles: [FamilyProfile] = []
    
    private let baseURL = AppConfig.API.baseURL
    
    // MARK: - Profile Management
    
    /// Validate stored profile ID against loaded profiles
    func validateStoredProfile(_ profiles: [FamilyProfile]) async {
        do {
            let storedProfileId = try KeychainManager.shared.retrieveSelectedProfile()
            
            #if DEBUG
            print("🔍 ProfileService: validateStoredProfile called")
            print("   - Stored profile ID: \(storedProfileId ?? "nil")")
            print("   - Available profiles: \(profiles.map { "\($0.name) (\($0.id))" }.joined(separator: ", "))")
            #endif
            
            if let storedProfileId = storedProfileId {
                if let foundProfile = profiles.first(where: { $0.id == storedProfileId }) {
                    await MainActor.run {
                        self.currentProfile = foundProfile
                        self.hasSelectedProfile = true
                    }
                    
                    #if DEBUG
                    print("✅ ProfileService: Validated and restored stored profile: \(foundProfile.name) (ID: \(foundProfile.id))")
                    #endif
                } else {
                    // Stored profile no longer exists, clear it
                    KeychainManager.shared.deleteSelectedProfile()
                    
                    await MainActor.run {
                        self.hasSelectedProfile = false
                        self.currentProfile = nil
                    }
                    
                    #if DEBUG
                    print("⚠️ ProfileService: Stored profile ID '\(storedProfileId)' not found in server profiles, cleared selection")
                    #endif
                }
            } else {
                await MainActor.run {
                    self.hasSelectedProfile = false
                    self.currentProfile = nil
                }
                
                #if DEBUG
                print("📝 ProfileService: No stored profile ID found, profile selection required")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ ProfileService: Error validating stored profile: \(error)")
            #endif
            
            await MainActor.run {
                self.hasSelectedProfile = false
                self.currentProfile = nil
            }
        }
    }
    
    /// Load all family profiles from backend
    func loadFamilyProfiles() async throws -> [FamilyProfile] {
        let endpoint = "\(baseURL)\(AppConfig.API.Endpoints.availableProfiles)"
        
        guard let url = URL(string: endpoint) else {
            throw ProfileError.invalidURL
        }
        
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw ProfileError.noToken
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProfileError.invalidResponse
        }
        
        #if DEBUG
        print("🌐 Load Family Profiles API Response Status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Load Family Profiles API Response: \(responseString)")
        }
        #endif
        
        guard 200...299 ~= httpResponse.statusCode else {
            // Try to decode API error message first, fallback to generic error
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw ProfileError.apiError(apiError.userMessage)
            } else {
                throw ProfileError.httpError(httpResponse.statusCode)
            }
        }
        
        do {
            let profilesResponse = try JSONDecoder().decode(FamilyProfilesResponse.self, from: data)
            
            // Convert AvailableProfile to FamilyProfile for UI compatibility
            let familyProfiles = profilesResponse.profiles.map { $0.toFamilyProfile() }
            
            await MainActor.run {
                self.availableProfiles = familyProfiles
            }
            
            return familyProfiles
        } catch {
            #if DEBUG
            print("❌ Family Profiles Decoding Error: \(error)")
            #endif
            throw ProfileError.decodingError
        }
    }
    
    /// Create new family profile
    func createFamilyProfile(_ request: CreateProfileRequest) async throws -> FamilyProfile {
        let endpoint = "\(baseURL)\(AppConfig.API.Endpoints.familyProfiles)"
        
        guard let url = URL(string: endpoint) else {
            throw ProfileError.invalidURL
        }
        
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw ProfileError.noToken
        }
        
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(request)
            httpRequest.httpBody = jsonData
            
            #if DEBUG
            if let requestString = String(data: jsonData, encoding: .utf8) {
                print("📤 Create Profile API Request: \(requestString)")
            }
            #endif
        } catch {
            throw ProfileError.encodingError
        }
        
        let (data, response) = try await URLSession.shared.data(for: httpRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProfileError.invalidResponse
        }
        
        #if DEBUG
        print("🌐 Create Profile API Response Status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Create Profile API Response: \(responseString)")
        }
        #endif
        
        guard 200...299 ~= httpResponse.statusCode else {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw ProfileError.apiError(apiError.userMessage)
            } else {
                throw ProfileError.httpError(httpResponse.statusCode)
            }
        }
        
        do {
            let createResponse = try JSONDecoder().decode(CreateProfileResponse.self, from: data)
            
            // Convert AdminProfile to FamilyProfile for UI compatibility
            let familyProfile = createResponse.profile.toFamilyProfile()
            
            await MainActor.run {
                self.availableProfiles.append(familyProfile)
            }
            
            return familyProfile
        } catch {
            #if DEBUG
            print("❌ Create Profile Decoding Error: \(error)")
            #endif
            throw ProfileError.decodingError
        }
    }
    
    /// Verify profile PIN
    func verifyProfilePIN(profileId: String, pin: String) async throws -> Bool {
        let endpoint = "\(baseURL)\(AppConfig.API.Endpoints.familyProfiles)/\(profileId)/verify-pin"
        
        guard let url = URL(string: endpoint) else {
            throw ProfileError.invalidURL
        }
        
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw ProfileError.noToken
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = VerifyPINRequest(pin: pin)
        
        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
            
            #if DEBUG
            if let requestString = String(data: jsonData, encoding: .utf8) {
                print("📤 Verify PIN API Request: \(requestString)")
            }
            #endif
        } catch {
            throw ProfileError.encodingError
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProfileError.invalidResponse
        }
        
        #if DEBUG
        print("🌐 Verify PIN API Response Status: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Verify PIN API Response: \(responseString)")
        }
        #endif
        
        if httpResponse.statusCode == 200 {
            // PIN verification successful
            return true
        } else {
            // Handle specific PIN errors with backend messages
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw ProfileError.pinVerificationFailed(apiError.userMessage)
            } else {
                throw ProfileError.httpError(httpResponse.statusCode)
            }
        }
    }
    
    /// Select a profile (calls backend API and stores locally)
    func selectProfile(_ profile: FamilyProfile, pin: String? = nil) async throws {
        let endpoint = "\(baseURL)\(AppConfig.API.Endpoints.selectProfile)"
        
        guard let url = URL(string: endpoint) else {
            throw ProfileError.invalidURL
        }
        
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw ProfileError.noToken
        }
        
        // Prepare request body
        var requestBody: [String: Any] = ["profileId": profile.id]
        if let pin = pin {
            requestBody["pin"] = pin
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        #if DEBUG
        print("📤 Profile Selection API Request:")
        print("   URL: \(endpoint)")
        print("   Profile ID: \(profile.id)")
        print("   Has PIN: \(pin != nil)")
        #endif
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProfileError.invalidResponse
        }
        
        #if DEBUG
        print("📥 Profile Selection API Response: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Response Body: \(responseString)")
        }
        #endif
        
        guard 200...299 ~= httpResponse.statusCode else {
            // Try to decode error message from API, fallback to generic error
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw ProfileError.apiError(apiError.userMessage)
            } else {
                throw ProfileError.httpError(httpResponse.statusCode)
            }
        }
        
        // Store profile locally in Keychain on successful API call
        try KeychainManager.shared.storeSelectedProfile(profile.id)
        
        await MainActor.run {
            self.currentProfile = profile
            self.hasSelectedProfile = true
        }
        
        #if DEBUG
        print("✅ ProfileService: Profile selected via API and stored locally")
        print("   - Profile name: \(profile.name)")
        print("   - Profile ID: \(profile.id)")
        print("   - Stored in keychain: ✅")
        print("   - Updated currentProfile: ✅") 
        print("   - Updated hasSelectedProfile: ✅")
        #endif
    }
    
    /// Get current active profile from backend
    func getCurrentProfile() async throws -> FamilyProfile? {
        let endpoint = "\(baseURL)/profiles/current"
        
        guard let url = URL(string: endpoint) else {
            throw ProfileError.invalidURL
        }
        
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw ProfileError.noToken
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        #if DEBUG
        print("📤 Get Current Profile API Request: \(endpoint)")
        #endif
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProfileError.invalidResponse
        }
        
        #if DEBUG
        print("📥 Get Current Profile API Response: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Response Body: \(responseString)")
        }
        #endif
        
        if httpResponse.statusCode == 404 {
            // No profile currently selected
            return nil
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw ProfileError.apiError(apiError.userMessage)
            } else {
                throw ProfileError.httpError(httpResponse.statusCode)
            }
        }
        
        do {
            let profile = try JSONDecoder().decode(FamilyProfile.self, from: data)
            return profile
        } catch {
            #if DEBUG
            print("❌ Failed to decode current profile: \(error)")
            #endif
            throw ProfileError.decodingError
        }
    }
    
    /// Check if user has a selected profile on startup (lightweight check)
    func checkSelectedProfile() async {
        do {
            let profileId = try KeychainManager.shared.retrieveSelectedProfile()
            
            await MainActor.run {
                if let profileId = profileId {
                    // We have a stored profile ID, assume it's valid for now
                    // Will validate when ProfileSelectionRequiredView loads profiles
                    self.hasSelectedProfile = true
                    
                    #if DEBUG
                    print("✅ Found stored profile ID: \(profileId)")
                    #endif
                } else {
                    self.hasSelectedProfile = false
                    
                    #if DEBUG
                    print("📝 No profile selected")
                    #endif
                }
            }
        } catch {
            await MainActor.run {
                self.hasSelectedProfile = false
            }
            
            #if DEBUG
            print("❌ Error checking selected profile: \(error)")
            #endif
        }
    }
    
    /// Clear selected profile (for logout)
    func clearSelectedProfile() {
        KeychainManager.shared.deleteSelectedProfile()
        currentProfile = nil
        hasSelectedProfile = false
        availableProfiles = []
        
        #if DEBUG
        print("🔄 Profile selection cleared")
        #endif
    }
    
    /// Update family profile
    func updateFamilyProfile(profileId: String, request: UpdateProfileRequest) async throws -> FamilyProfile {
        let endpoint = "\(baseURL)\(AppConfig.API.Endpoints.familyProfiles)/\(profileId)"
        
        guard let url = URL(string: endpoint) else {
            throw ProfileError.invalidURL
        }
        
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw ProfileError.noToken
        }
        
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "PUT"
        httpRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(request)
            httpRequest.httpBody = jsonData
        } catch {
            throw ProfileError.encodingError
        }
        
        let (data, response) = try await URLSession.shared.data(for: httpRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProfileError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw ProfileError.apiError(apiError.userMessage)
            } else {
                throw ProfileError.httpError(httpResponse.statusCode)
            }
        }
        
        do {
            let updateResponse = try JSONDecoder().decode(UpdateProfileResponse.self, from: data)
            
            // Update local profiles array
            await MainActor.run {
                if let index = self.availableProfiles.firstIndex(where: { $0.id == profileId }) {
                    self.availableProfiles[index] = updateResponse.profile
                }
                
                // Update current profile if it's the one being updated
                if self.currentProfile?.id == profileId {
                    self.currentProfile = updateResponse.profile
                }
            }
            
            return updateResponse.profile
        } catch {
            throw ProfileError.decodingError
        }
    }
    
    /// Delete family profile
    func deleteFamilyProfile(profileId: String) async throws {
        let endpoint = "\(baseURL)\(AppConfig.API.Endpoints.familyProfiles)/\(profileId)"
        
        guard let url = URL(string: endpoint) else {
            throw ProfileError.invalidURL
        }
        
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw ProfileError.noToken
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProfileError.invalidResponse
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw ProfileError.apiError(apiError.userMessage)
            } else {
                throw ProfileError.httpError(httpResponse.statusCode)
            }
        }
        
        // Remove from local profiles array
        await MainActor.run {
            self.availableProfiles.removeAll { $0.id == profileId }
            
            // If we deleted the current profile, clear selection
            if self.currentProfile?.id == profileId {
                self.clearSelectedProfile()
            }
        }
    }
}

// MARK: - Profile Error Types
enum ProfileError: LocalizedError {
    case invalidURL
    case noToken
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case pinVerificationFailed(String)
    case encodingError
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noToken:
            return "No authentication token found"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .apiError(let message):
            return message // Use backend error message directly
        case .pinVerificationFailed(let message):
            return message // Use backend PIN error message directly
        case .encodingError:
            return "Failed to encode request"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}

// MARK: - API Models


struct UpdateProfileResponse: Codable {
    let message: String
    let profile: FamilyProfile
}

struct VerifyPINRequest: Codable {
    let pin: String
}

struct VerifyPINResponse: Codable {
    let success: Bool
    let profileId: String
    let message: String
}