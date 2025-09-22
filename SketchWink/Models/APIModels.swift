import Foundation

// MARK: - Common API Models

/// Standard API error response structure
struct APIError: Codable {
    let error: String
    let message: String?
    let statusCode: Int?
    
    /// Use error message if available, fallback to message field
    var userMessage: String {
        return error
    }
}

// MARK: - User Permissions

/// User permissions and subscription information
struct UserPermissions: Codable {
    let hasQualitySelector: Bool
    let hasModelSelector: Bool
    let hasCommercialLicense: Bool
    let hasImageUpload: Bool
    let maxFamilyProfiles: Int
    let maxImagesPerGeneration: Int
    let availableModels: [String]
    let availableQuality: [String]
    let accountType: String
    let planName: String
    let isTrialing: Bool
    let trialEndsAt: String?
    let limitations: String?
}

/// Token balance response with permissions
struct TokenBalanceResponse: Codable {
    let subscriptionTokens: Int
    let purchasedTokens: Int
    let totalTokens: Int
    let permissions: UserPermissions
}

// MARK: - Subscription Plans

/// Subscription plan model
struct SubscriptionPlan: Identifiable, Codable {
    let id: String
    let name: String
    let displayName: String
    let description: String
    let monthlyPrice: Double?
    let yearlyPrice: Double?
    let monthlyTokens: Int
    let features: [String]
    let isPopular: Bool
    let color: String?
    let maxImagesPerGeneration: Int
    let hasQualitySelector: Bool
    let hasModelSelector: Bool
    let availableModels: [String]
    let availableQuality: [String]
    
    /// Computed properties for UI
    var isFree: Bool {
        return id == "free"
    }
    
    var monthlyPriceString: String {
        guard let price = monthlyPrice, price > 0 else { return "Free" }
        return String(format: "$%.0f", price)
    }
    
    var yearlyPriceString: String {
        guard let price = yearlyPrice, price > 0 else { return "Free" }
        return String(format: "$%.0f", price)
    }
    
    var monthlySavings: String? {
        guard let monthly = monthlyPrice, let yearly = yearlyPrice, monthly > 0, yearly > 0 else { return nil }
        let yearlyMonthly = yearly / 12
        let savings = ((monthly - yearlyMonthly) / monthly) * 100
        return String(format: "%.0f%% off", savings)
    }
}

// MARK: - Family Profiles

/// Family profile model
struct FamilyProfile: Identifiable, Codable {
    let id: String
    let name: String
    let avatar: String?
    let isDefault: Bool
    let canMakePurchases: Bool
    let canUseCustomContentTypes: Bool
    let hasPin: Bool  // PIN existence (actual PIN never exposed)
    let createdAt: String
    let updatedAt: String
    
    /// UI helper for avatar display
    var displayAvatar: String {
        return avatar ?? "👤"
    }
    
    /// UI helper for profile color based on name
    var profileColor: String {
        let colors = ["#37B6F6", "#882FF6", "#FF6B9D", "#10B981", "#F97316"]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }
}

/// Create profile request
struct CreateProfileRequest: Codable {
    let name: String
    let avatar: String?
    let pin: String?
    let canMakePurchases: Bool
    let canUseCustomContentTypes: Bool
}

/// Update profile request
struct UpdateProfileRequest: Codable {
    let name: String?
    let avatar: String?
    let pin: String?
    let canMakePurchases: Bool?
    let canUseCustomContentTypes: Bool?
}

/// Profile selection request
struct SelectProfileRequest: Codable {
    let profileId: String
    let pin: String?  // Required if profile has PIN protection
}

/// Profile selection response
struct SelectProfileResponse: Codable {
    let success: Bool
    let message: String
    let selectedProfile: FamilyProfile?
}