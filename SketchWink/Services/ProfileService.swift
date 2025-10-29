import Foundation
import Combine
import SwiftUI

// MARK: - Profile Service
class ProfileService: ObservableObject {
    static let shared = ProfileService()
    private init() {}
    
    @Published var hasSelectedProfile = false
    @Published var currentProfile: FamilyProfile?
    @Published var availableProfiles: [FamilyProfile] = []
    @Published var serverStatus: ServerStatus = .available
    
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
            await MainActor.run {
                self.serverStatus = .invalidConfiguration
            }
            throw ProfileError.invalidURL
        }
        
        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw ProfileError.noToken
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0 // 10 second timeout
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await MainActor.run {
                    self.serverStatus = .serverDown("Invalid response from server")
                }
                throw ProfileError.invalidResponse
            }
            
            #if DEBUG
            print("🌐 Load Family Profiles API Response Status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Load Family Profiles API Response: \(responseString)")
            }
            #endif
            
            // Reset server status on successful connection
            await MainActor.run {
                self.serverStatus = .available
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                // Handle unauthorized responses by automatically logging out
                if httpResponse.statusCode == 401 {
                    AuthService.handleUnauthorizedResponse()
                }
                
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
        } catch {
            // Handle different types of network connectivity issues
            await MainActor.run {
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                        // These are actual server issues - show full screen
                        self.serverStatus = .serverDown("Cannot reach SketchWink servers. They might be temporarily down.")
                    case .secureConnectionFailed:
                        // SSL/Security issues are server-side - show full screen
                        self.serverStatus = .serverDown("Secure connection failed. Please try again later.")
                    case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                        // These are client/network issues - keep available but let banner handle it
                        self.serverStatus = .available
                    default:
                        // Other errors - keep available but let banner handle it
                        self.serverStatus = .available
                    }
                } else {
                    // Non-URL errors - keep available but let banner handle it
                    self.serverStatus = .available
                }
            }
            
            #if DEBUG
            print("❌ Network Error loading profiles: \(error)")
            print("🔍 Error type: \(type(of: error))")
            if let urlError = error as? URLError {
                print("🔍 URLError code: \(urlError.code)")
                print("🔍 Will show full screen: \(urlError.code == .cannotConnectToHost || urlError.code == .cannotFindHost || urlError.code == .dnsLookupFailed || urlError.code == .secureConnectionFailed)")
            }
            #endif
            
            // Re-throw as network error for better handling
            throw ProfileError.networkError(error.localizedDescription)
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

        // Only require admin profile if user has existing profiles
        // For first-time users (no profiles), allow creation without X-Profile-ID header
        if !availableProfiles.isEmpty {
            // User has existing profiles - require admin privileges
            guard let currentProfile = self.currentProfile, currentProfile.isDefault else {
                throw ProfileError.apiError("Only the main family profile can manage family settings.")
            }
            httpRequest.setValue(currentProfile.id, forHTTPHeaderField: "X-Profile-ID") // Required for admin access

            #if DEBUG
            print("📋 CreateProfile: User has existing profiles, using admin profile ID: \(currentProfile.id)")
            #endif
        } else {
            #if DEBUG
            print("📋 CreateProfile: First-time user (no existing profiles), creating without X-Profile-ID header")
            #endif
        }
        
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
            // Handle unauthorized responses by automatically logging out
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                AuthService.handleUnauthorizedResponse()
            }
            
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
            withAnimation(.easeInOut(duration: 0.35)) {
                self.currentProfile = profile
                self.hasSelectedProfile = true
            }
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
            // Handle unauthorized responses by automatically logging out
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                AuthService.handleUnauthorizedResponse()
            }
            
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
        serverStatus = .available
        
        #if DEBUG
        print("🔄 Profile selection cleared")
        #endif
    }
    
    /// Reset server status (for retry attempts)
    func resetServerStatus() {
        serverStatus = .available
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
        
        // Ensure we have a current profile with admin privileges
        guard let currentProfile = self.currentProfile, currentProfile.isDefault else {
            throw ProfileError.apiError("Only the main family profile can manage family settings.")
        }
        
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "PUT"
        httpRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        httpRequest.setValue(currentProfile.id, forHTTPHeaderField: "X-Profile-ID") // Required for admin access
        
        do {
            let jsonData = try JSONEncoder().encode(request)
            httpRequest.httpBody = jsonData
            
            #if DEBUG
            print("📤 Update Profile Request Details:")
            print("   - URL: \(endpoint)")
            print("   - Method: PUT")
            print("   - Headers: Authorization: Bearer [token], Content-Type: application/json, X-Profile-ID: \(currentProfile.id)")
            if let requestString = String(data: jsonData, encoding: .utf8) {
                print("   - Body: \(requestString)")
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
        print("📥 Update Profile API Response: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Response Body: \(responseString)")
        } else {
            print("📥 Response Body: Unable to decode as UTF-8")
        }
        #endif
        
        guard 200...299 ~= httpResponse.statusCode else {
            // Handle unauthorized responses by automatically logging out
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                AuthService.handleUnauthorizedResponse()
            }
            
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw ProfileError.apiError(apiError.userMessage)
            } else {
                throw ProfileError.httpError(httpResponse.statusCode)
            }
        }
        
        do {
            #if DEBUG
            print("🔄 Attempting to decode wrapped profile response from response data...")
            #endif
            
            // Decode the wrapper response with message and profile
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            guard let profileData = json?["profile"] as? [String: Any] else {
                throw ProfileError.decodingError
            }
            
            // Convert profile dictionary back to Data and decode as AdminProfile
            let profileJsonData = try JSONSerialization.data(withJSONObject: profileData)
            let adminProfile = try JSONDecoder().decode(AdminProfile.self, from: profileJsonData)
            let familyProfile = adminProfile.toFamilyProfile()
            
            #if DEBUG
            print("✅ Successfully decoded wrapped profile response")
            print("   - Message: \(json?["message"] as? String ?? "No message")")
            print("   - Profile ID: \(familyProfile.id)")
            print("   - Profile Name: \(familyProfile.name)")
            print("   - Can Make Purchases: \(familyProfile.canMakePurchases)")
            print("   - Can Use Custom Content: \(familyProfile.canUseCustomContentTypes)")
            #endif
            
            // Update local profiles array
            await MainActor.run {
                if let index = self.availableProfiles.firstIndex(where: { $0.id == profileId }) {
                    self.availableProfiles[index] = familyProfile
                }
                
                // Update current profile if it's the one being updated
                if self.currentProfile?.id == profileId {
                    self.currentProfile = familyProfile
                }
            }
            
            return familyProfile
        } catch {
            #if DEBUG
            print("❌ Failed to decode UpdateProfileResponse: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ Raw response that failed to decode: \(responseString)")
            }
            #endif
            throw ProfileError.decodingError
        }
    }

    /// Update or clear the PIN for a family profile
    func updateProfilePIN(profileId: String, newPIN: String?) async throws -> FamilyProfile {
        let endpoint = "\(baseURL)\(AppConfig.API.Endpoints.familyProfiles)/\(profileId)"

        guard let url = URL(string: endpoint) else {
            throw ProfileError.invalidURL
        }

        guard let token = try KeychainManager.shared.retrieveToken() else {
            throw ProfileError.noToken
        }

        guard let adminProfile = self.currentProfile, adminProfile.isDefault else {
            throw ProfileError.apiError("Only the main family profile can manage family settings.")
        }

        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "PUT"
        httpRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        httpRequest.setValue(adminProfile.id, forHTTPHeaderField: "X-Profile-ID")

        var payload: [String: Any] = [:]
        if let newPIN {
            payload["pin"] = newPIN
        } else {
            payload["pin"] = NSNull()
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload)
            httpRequest.httpBody = jsonData

            #if DEBUG
            print("📤 Update Profile PIN Request")
            print("   - Profile ID: \(profileId)")
            print("   - Action: \(newPIN == nil ? "remove" : "set")")
            print("   - Endpoint: \(endpoint)")
            #endif
        } catch {
            throw ProfileError.encodingError
        }

        let (data, response) = try await URLSession.shared.data(for: httpRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProfileError.invalidResponse
        }

        #if DEBUG
        print("📥 Update Profile PIN API Response: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Response Body: \(responseString)")
        }
        #endif

        guard 200...299 ~= httpResponse.statusCode else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                AuthService.handleUnauthorizedResponse()
            }

            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw ProfileError.apiError(apiError.userMessage)
            } else {
                throw ProfileError.httpError(httpResponse.statusCode)
            }
        }

        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            guard let profileDictionary = jsonObject?["profile"] as? [String: Any] else {
                throw ProfileError.decodingError
            }

            let profileData = try JSONSerialization.data(withJSONObject: profileDictionary)
            let adminProfileResponse = try JSONDecoder().decode(AdminProfile.self, from: profileData)
            let updatedProfile = adminProfileResponse.toFamilyProfile()

            await MainActor.run {
                if let index = self.availableProfiles.firstIndex(where: { $0.id == profileId }) {
                    self.availableProfiles[index] = updatedProfile
                }

                if self.currentProfile?.id == updatedProfile.id {
                    self.currentProfile = updatedProfile
                }
            }

            return updatedProfile
        } catch {
            #if DEBUG
            print("❌ Failed to decode updateProfilePIN response: \(error)")
            #endif
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

        // Ensure we have a current profile with admin privileges
        guard let currentProfile = self.currentProfile, currentProfile.isDefault else {
            throw ProfileError.apiError("Only the main family profile can manage family settings.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(currentProfile.id, forHTTPHeaderField: "X-Profile-ID") // Required for admin access

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProfileError.invalidResponse
        }

        guard 200...299 ~= httpResponse.statusCode else {
            // Handle unauthorized responses by automatically logging out
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                AuthService.handleUnauthorizedResponse()
            }

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

    /// Request PIN recovery email for a family profile
    /// Sends the profile's PIN to the account owner's email
    func forgotProfilePIN(profileId: String) async throws {
        let endpoint = "\(baseURL)\(AppConfig.API.Endpoints.forgotProfilePIN)"

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

        let requestBody = ForgotPINRequest(profileId: profileId)

        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData

            #if DEBUG
            print("📤 Forgot Profile PIN API Request")
            print("   - URL: \(endpoint)")
            print("   - Profile ID: \(profileId)")
            #endif
        } catch {
            throw ProfileError.encodingError
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProfileError.invalidResponse
        }

        #if DEBUG
        print("📥 Forgot Profile PIN API Response: \(httpResponse.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Response Body: \(responseString)")
        }
        #endif

        guard 200...299 ~= httpResponse.statusCode else {
            // Handle unauthorized responses by automatically logging out
            if httpResponse.statusCode == 401 {
                AuthService.handleUnauthorizedResponse()
            }

            // Try to decode API error message first, fallback to generic error
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw ProfileError.apiError(apiError.userMessage)
            } else {
                throw ProfileError.httpError(httpResponse.statusCode)
            }
        }

        // Success - PIN recovery email sent
        #if DEBUG
        print("✅ PIN recovery email sent successfully for profile: \(profileId)")
        #endif
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
    case networkError(String)
    
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
        case .networkError(let message):
            return message // Network connectivity error
        }
    }
}

// MARK: - Server Status Types
enum ServerStatus {
    case available
    case networkError(String)      // No internet, connection lost
    case serverDown(String)         // Server unreachable, maintenance
    case timeout(String)           // Request timeout
    case invalidConfiguration      // Invalid URL or config issue
    
    var isUnavailable: Bool {
        switch self {
        case .available:
            return false
        default:
            return true
        }
    }
    
    var errorMessage: String {
        switch self {
        case .available:
            return ""
        case .networkError(let message):
            return message
        case .serverDown(let message):
            return message
        case .timeout(let message):
            return message
        case .invalidConfiguration:
            return "App configuration error"
        }
    }
    
    var errorType: String {
        switch self {
        case .available:
            return "available"
        case .networkError:
            return "network"
        case .serverDown:
            return "server"
        case .timeout:
            return "timeout"
        case .invalidConfiguration:
            return "config"
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
