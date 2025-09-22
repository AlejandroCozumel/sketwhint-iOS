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