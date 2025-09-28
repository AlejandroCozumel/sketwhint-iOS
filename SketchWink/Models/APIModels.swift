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

// MARK: - User Permissions & Token Balance

/// Subscription limitations and upgrade messaging
struct SubscriptionLimitations: Codable {
    let message: String
    let modelRestriction: String
    let qualityRestriction: String
    let upgradeMessage: String
}

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
    let trialEndsAt: String?  // Can be null in API
    let limitations: SubscriptionLimitations?  // Can be null in API
    
    /// Get limitations with default values if API returns null
    var effectiveLimitations: SubscriptionLimitations {
        return limitations ?? SubscriptionLimitations(
            message: "No restrictions",
            modelRestriction: "All models available",
            qualityRestriction: "All qualities available",
            upgradeMessage: "You have full access to all features"
        )
    }
}

/// Complete token balance response with permissions
struct TokenBalanceResponse: Codable {
    let subscriptionTokens: Int
    let purchasedTokens: Int
    let totalTokens: Int
    let lastSubscriptionRefresh: String?  // Can be null in API
    let maxRollover: Int                   // Always present as number
    private let _currentPlan: CurrentPlanWrapper // Internal flexible field
    let permissions: UserPermissions
    
    /// Get current plan as string regardless of API format
    var currentPlan: String {
        return _currentPlan.value
    }
    
    // Custom decoder to handle currentPlan flexibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        subscriptionTokens = try container.decode(Int.self, forKey: .subscriptionTokens)
        purchasedTokens = try container.decode(Int.self, forKey: .purchasedTokens)
        totalTokens = try container.decode(Int.self, forKey: .totalTokens)
        lastSubscriptionRefresh = try container.decodeIfPresent(String.self, forKey: .lastSubscriptionRefresh)
        maxRollover = try container.decode(Int.self, forKey: .maxRollover)
        permissions = try container.decode(UserPermissions.self, forKey: .permissions)
        
        // Handle currentPlan as either string or object
        _currentPlan = try container.decode(CurrentPlanWrapper.self, forKey: .currentPlan)
    }
    
    // Custom encoder to maintain Encodable conformance
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(subscriptionTokens, forKey: .subscriptionTokens)
        try container.encode(purchasedTokens, forKey: .purchasedTokens)
        try container.encode(totalTokens, forKey: .totalTokens)
        try container.encodeIfPresent(lastSubscriptionRefresh, forKey: .lastSubscriptionRefresh)
        try container.encode(maxRollover, forKey: .maxRollover)
        try container.encode(permissions, forKey: .permissions)
        
        // Encode currentPlan as simple string
        try container.encode(currentPlan, forKey: .currentPlan)
    }
    
    private enum CodingKeys: String, CodingKey {
        case subscriptionTokens, purchasedTokens, totalTokens, lastSubscriptionRefresh, maxRollover, currentPlan, permissions
    }
}

/// Wrapper to handle currentPlan as string or complex object
private struct CurrentPlanWrapper: Codable {
    let value: String
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let stringValue = try? container.decode(String.self) {
            // currentPlan is a simple string
            value = stringValue
        } else if let planObject = try? container.decode(PlanObject.self) {
            // currentPlan is a complex object - use the name field
            value = planObject.name
        } else {
            // Fallback for any other format
            value = "Unknown Plan"
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

/// Simple struct to decode just the fields we need from currentPlan object
private struct PlanObject: Codable {
    let id: String?
    let name: String
    let description: String?
    
    // We can ignore all other fields by not declaring them
}

extension TokenBalanceResponse {
    /// UI helpers
    var hasTokens: Bool {
        return totalTokens > 0
    }
    
    var canGenerate: Bool {
        return totalTokens > 0
    }
    
    var displayTotalTokens: String {
        return "\(totalTokens)"
    }
    
    var planDisplayName: String {
        return permissions.planName
    }
    
    var accountTypeDisplay: String {
        return permissions.accountType.capitalized
    }
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

/// Response wrapper for available profiles from /profiles/available
struct FamilyProfilesResponse: Codable {
    let profiles: [AvailableProfile]
}

/// Simplified profile model for /profiles/available endpoint (user selection)
struct AvailableProfile: Identifiable, Codable {
    let id: String
    let name: String
    let avatar: String?
    let hasPin: Bool  // Boolean indicator only (no actual PIN)
    let canMakePurchases: Bool
    let isDefault: Bool
    
    /// Convert to FamilyProfile for compatibility with existing UI
    func toFamilyProfile() -> FamilyProfile {
        return FamilyProfile(
            id: id,
            name: name,
            avatar: avatar,
            isDefault: isDefault,
            canMakePurchases: canMakePurchases,
            canUseCustomContentTypes: false, // Default value since not provided
            hasPin: hasPin,
            createdAt: "", // Not provided in available profiles
            updatedAt: ""  // Not provided in available profiles
        )
    }
}

/// Full profile model for admin operations (/family-profiles endpoints)
struct AdminProfile: Identifiable, Codable {
    let id: String
    let userId: String
    let name: String
    let avatar: String?
    let pin: String?  // Actual PIN value (admin view)
    let canMakePurchases: Bool
    let canUseCustomContentTypes: Bool
    let isDefault: Bool
    let createdAt: String
    let updatedAt: String
    
    /// Convert to FamilyProfile for UI compatibility
    func toFamilyProfile() -> FamilyProfile {
        return FamilyProfile(
            id: id,
            name: name,
            avatar: avatar,
            isDefault: isDefault,
            canMakePurchases: canMakePurchases,
            canUseCustomContentTypes: canUseCustomContentTypes,
            hasPin: pin != nil, // Convert PIN to boolean indicator
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

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
    // isDefault is automatically set by backend for first profile
}

/// Create profile response wrapper
struct CreateProfileResponse: Codable {
    let profile: AdminProfile
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

// MARK: - Content Creation Models

/// Information about who created a piece of content
struct CreatedBy: Codable {
    let profileId: String?
    let profileName: String?
}