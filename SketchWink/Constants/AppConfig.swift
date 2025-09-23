import Foundation
import SwiftUI

/// App configuration constants for SketchWink
/// Central place for all app settings, URLs, limits, and feature flags
struct AppConfig {
    
    // MARK: - App Information
    static let appName = "SketchWink"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.sketchwink.app"
    
    // MARK: - API Configuration
    struct API {
        #if DEBUG
        static let baseURL = "http://127.0.0.1:3000/api"  // Include /api in baseURL
        #else
        static let baseURL = "https://api.sketchwink.com/api"
        #endif
        
        static let timeout: TimeInterval = 30
        static let maxRetries = 3
        
        // API Endpoints (baseURL already includes /api)
        struct Endpoints {
            // Authentication
            static let signUp = "/auth/sign-up"          // POST - Create new account
            static let signIn = "/auth/sign-in"          // POST - Login user
            static let verifyOTP = "/verify-otp"         // POST - Verify email OTP
            static let resendOTP = "/auth/resend-otp"    // POST - Resend verification OTP
            static let refreshToken = "/auth/refresh"     // POST - Refresh access token
            
            // User & Profiles
            static let profiles = "/profiles"
            static let availableProfiles = "/profiles/available"
            static let selectProfile = "/profiles/select"
            static let familyProfiles = "/family-profiles"
            
            // Content Generation
            static let categories = "/categories/with-options"
            static let generations = "/generations"
            static let enhancePrompt = "/prompt/enhance"
            
            // Images & Downloads
            static let images = "/images"
            static let imageDownload = "/images/%@/download" // %@ = imageId
            static let toggleFavorite = "/generated-images/%@/favorite" // %@ = imageId
            static let bulkFavorite = "/images/bulk-favorite"
            
            // Collections
            static let collections = "/collections"
            static let collectionImages = "/collections/%@/images" // %@ = collectionId
            static let bulkAddToCollection = "/collections/%@/bulk-add" // %@ = collectionId
            
            // User Settings
            static let promptEnhancementSettings = "/user/settings/prompt-enhancement"
            
            // Subscription & Billing
            static let subscriptionPlans = "/subscription-plans"
            static let tokenBalance = "/user/token-balance"
            
            // Analytics
            static let analytics = "/analytics"
            
            // Server-Sent Events (SSE)
            static let sseGenerationProgress = "/sse/generation-progress/%@" // %@ = generationId
            static let sseUserProgress = "/sse/user-progress"
        }
    }
    
    // MARK: - Content Categories
    struct Categories {
        static let coloringPages = "coloring_pages"
        static let stickers = "stickers"
        static let wallpapers = "wallpapers"
        static let mandalas = "mandalas"
        
        static let all = [coloringPages, stickers, wallpapers, mandalas]
        
        struct Icons {
            static let coloringPages = "🎨"
            static let stickers = "✨"
            static let wallpapers = "🖼️"
            static let mandalas = "🌸"
        }
    }
    
    // MARK: - Generation Limits
    struct Generation {
        static let maxImagesPerGeneration = 4
        static let minImagesPerGeneration = 1
        static let defaultImageCount = 1
        
        static let maxPromptLength = 500
        static let minPromptLength = 3
        
        static let defaultQuality = "standard"
        static let defaultDimensions = "1:1"
        static let defaultModel = "seedream"
        
        struct Quality {
            static let standard = "standard"
            static let high = "high"
            static let ultra = "ultra"
            
            static let all = [standard, high, ultra]
        }
        
        struct Dimensions {
            static let square = "1:1"
            static let portrait = "2:3"
            static let landscape = "3:2"
            static let a4 = "a4"
            
            static let all = [square, portrait, landscape, a4]
        }
        
        struct Models {
            static let seedream = "seedream"
            static let flux = "flux"
            
            static let all = [seedream, flux]
        }
        
        // Token costs per generation
        struct TokenCosts {
            static let coloringPages = 1
            static let stickers = 1
            static let wallpapers = 1
            static let mandalas = 1
        }
        
        // Polling configuration for generation status
        static let pollingInterval: TimeInterval = 2.0
        static let maxPollingDuration: TimeInterval = 300.0 // 5 minutes
    }
    
    // MARK: - Family & Parental Controls
    struct Family {
        static let maxProfilesPerFamily = 6
        static let maxPinAttempts = 3
        static let pinLength = 4
        
        static let childSafeAgeMin = 4
        static let childSafeAgeMax = 12
        
        struct DefaultAvatars {
            static let child = ["👶", "🧒", "👧", "👦", "🐶", "🐱", "🦄", "🌈"]
            static let parent = ["👨", "👩", "👨‍💼", "👩‍💼", "👨‍🏫", "👩‍🏫"]
        }
    }
    
    // MARK: - Image & File Handling
    struct Images {
        static let maxFileSize: Int64 = 50 * 1024 * 1024 // 50MB
        static let allowedFormats = ["jpg", "jpeg", "png", "webp", "pdf"]
        static let defaultFormat = "png"
        static let defaultQuality = 95
        
        static let thumbnailSize: CGFloat = 150
        static let previewSize: CGFloat = 400
        static let maxImageDimension: CGFloat = 2048
        
        // Caching
        static let cacheExpirationDays = 7
        static let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500MB
    }
    
    // MARK: - User Interface
    struct UI {
        static let animationDuration: TimeInterval = 0.3
        static let hapticEnabled = true
        
        // Child-friendly settings
        static let minFontSize: CGFloat = 12
        static let maxFontSize: CGFloat = 24
        static let minTouchTarget: CGFloat = 44
        static let recommendedTouchTarget: CGFloat = 56
        
        // Grid layouts
        static let maxColumnsPhone = 2
        static let maxColumnsTablet = 3
        
        struct Timeouts {
            static let alertDismissal: TimeInterval = 3.0
            static let toastDuration: TimeInterval = 2.0
            static let loadingTimeout: TimeInterval = 30.0
        }
    }
    
    // MARK: - Security & Privacy
    struct Security {
        static let keychainService = "com.sketchwink.keychain"
        static let tokenKey = "user_token"
        static let profileKey = "selected_profile"
        
        // Session management
        static let sessionTimeoutMinutes = 30
        static let refreshTokenBeforeExpiryMinutes = 5
        
        // Content filtering
        static let enableContentFiltering = true
        static let reportInappropriateContent = true
    }
    
    // MARK: - Subscription Plans
    struct Subscriptions {
        struct PlanIDs {
            static let free = "free"
            static let basicMonthly = "basic_monthly"
            static let basicYearly = "basic_yearly"
            static let proMonthly = "pro_monthly"
            static let proYearly = "pro_yearly"
            static let maxMonthly = "max_monthly"
            static let maxYearly = "max_yearly"
            static let businessMonthly = "business_monthly"
            static let businessYearly = "business_yearly"
        }
        
        struct Features {
            static let freeTokens = 3
            static let basicMonthlyTokens = 100
            static let proMonthlyTokens = 300
            static let maxMonthlyTokens = 600
            static let businessMonthlyTokens = 2000
        }
        
        // Apple In-App Purchase Product IDs
        struct AppleProductIDs {
            static let basicMonthly = "com.sketchwink.basic.monthly"
            static let basicYearly = "com.sketchwink.basic.yearly"
            static let proMonthly = "com.sketchwink.pro.monthly"
            static let proYearly = "com.sketchwink.pro.yearly"
            static let maxMonthly = "com.sketchwink.max.monthly"
            static let maxYearly = "com.sketchwink.max.yearly"
            static let businessMonthly = "com.sketchwink.business.monthly"
            static let businessYearly = "com.sketchwink.business.yearly"
        }
    }
    
    // MARK: - Analytics & Tracking
    struct Analytics {
        static let enableAnalytics = true
        static let enableCrashReporting = true
        
        struct Events {
            static let appLaunched = "app_launched"
            static let userSignedIn = "user_signed_in"
            static let profileSelected = "profile_selected"
            static let generationStarted = "generation_started"
            static let generationCompleted = "generation_completed"
            static let imageDownloaded = "image_downloaded"
            static let subscriptionPurchased = "subscription_purchased"
        }
    }
    
    // MARK: - Feature Flags
    struct FeatureFlags {
        static let enablePromptEnhancement = true
        static let enableVoiceInput = false
        static let enableOfflineMode = false
        static let enableSocialSharing = false // Disabled for child safety
        static let enableBetaFeatures = false
        
        #if DEBUG
        static let enableDebugMenu = true
        static let enableTestData = true
        #else
        static let enableDebugMenu = false
        static let enableTestData = false
        #endif
    }
    
    // MARK: - External Services
    struct ExternalServices {
        struct AppleServices {
            static let appStoreURL = "https://apps.apple.com/app/sketchwink/id123456789"
            static let supportURL = "https://support.sketchwink.com"
            static let privacyPolicyURL = "https://sketchwink.com/privacy"
            static let termsOfServiceURL = "https://sketchwink.com/terms"
        }
        
        struct ContactInfo {
            static let supportEmail = "support@sketchwink.com"
            static let feedbackEmail = "feedback@sketchwink.com"
            static let businessEmail = "business@sketchwink.com"
        }
    }
    
    // MARK: - Development & Debug
    struct Debug {
        #if DEBUG
        static let enableLogging = true
        static let logLevel = "DEBUG"
        static let enableNetworkLogging = true
        static let enablePerformanceMonitoring = true
        #else
        static let enableLogging = false
        static let logLevel = "ERROR"
        static let enableNetworkLogging = false
        static let enablePerformanceMonitoring = false
        #endif
        
        static let mockDataEnabled = false
        static let skipOnboarding = false
        static let autoSignIn = false
    }
}

// MARK: - Environment Detection
extension AppConfig {
    
    /// Returns true if running in debug mode
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    /// Returns true if running in simulator
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    /// Returns true if running on iPad
    static var isIPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    /// Returns the current environment name
    static var environmentName: String {
        if isDebug {
            return "Development"
        } else {
            return "Production"
        }
    }
}

// MARK: - Validation Helpers
extension AppConfig {
    
    /// Validates if a prompt meets length requirements
    static func isValidPromptLength(_ prompt: String) -> Bool {
        let length = prompt.trimmingCharacters(in: .whitespacesAndNewlines).count
        return length >= Generation.minPromptLength && length <= Generation.maxPromptLength
    }
    
    /// Validates if an image count is within limits
    static func isValidImageCount(_ count: Int) -> Bool {
        return count >= Generation.minImagesPerGeneration && count <= Generation.maxImagesPerGeneration
    }
    
    /// Validates if a PIN meets requirements
    static func isValidPIN(_ pin: String) -> Bool {
        return pin.count == Family.pinLength && pin.allSatisfy { $0.isNumber }
    }
    
    /// Returns the appropriate API URL for the current environment
    static func apiURL(for endpoint: String) -> String {
        return API.baseURL + endpoint
    }
}

// MARK: - Constants Usage Example
#if DEBUG
struct ConfigPreview: View {
    var body: some View {
        NavigationView {
            List {
                Section("App Info") {
                    HStack {
                        Text("App Name")
                        Spacer()
                        Text(AppConfig.appName)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("\(AppConfig.appVersion) (\(AppConfig.buildNumber))")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Environment")
                        Spacer()
                        Text(AppConfig.environmentName)
                            .foregroundColor(AppConfig.isDebug ? .orange : .green)
                    }
                }
                
                Section("API Configuration") {
                    HStack {
                        Text("Base URL")
                        Spacer()
                        Text(AppConfig.API.baseURL)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    HStack {
                        Text("Timeout")
                        Spacer()
                        Text("\(Int(AppConfig.API.timeout))s")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Generation Limits") {
                    HStack {
                        Text("Max Images")
                        Spacer()
                        Text("\(AppConfig.Generation.maxImagesPerGeneration)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Max Prompt Length")
                        Spacer()
                        Text("\(AppConfig.Generation.maxPromptLength)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Polling Interval")
                        Spacer()
                        Text("\(AppConfig.Generation.pollingInterval)s")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Feature Flags") {
                    HStack {
                        Text("Prompt Enhancement")
                        Spacer()
                        Image(systemName: AppConfig.FeatureFlags.enablePromptEnhancement ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundColor(AppConfig.FeatureFlags.enablePromptEnhancement ? .green : .red)
                    }
                    
                    HStack {
                        Text("Voice Input")
                        Spacer()
                        Image(systemName: AppConfig.FeatureFlags.enableVoiceInput ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundColor(AppConfig.FeatureFlags.enableVoiceInput ? .green : .red)
                    }
                    
                    HStack {
                        Text("Debug Menu")
                        Spacer()
                        Image(systemName: AppConfig.FeatureFlags.enableDebugMenu ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundColor(AppConfig.FeatureFlags.enableDebugMenu ? .green : .red)
                    }
                }
            }
            .navigationTitle("App Configuration")
        }
    }
}

#Preview {
    ConfigPreview()
}
#endif