import Foundation
import SwiftUI
import Combine

// MARK: - Token Balance Loading State
enum TokenBalanceLoadingState {
    case idle
    case loading
    case loaded(TokenBalanceResponse)
    case error(TokenBalanceError)
    
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    var tokenBalance: TokenBalanceResponse? {
        if case .loaded(let balance) = self {
            return balance
        }
        return nil
    }
    
    var error: TokenBalanceError? {
        if case .error(let error) = self {
            return error
        }
        return nil
    }
}

// MARK: - Global Token Balance Manager
/// Global singleton manager for token balance state throughout the app
/// Provides real-time token balance and permissions information
@MainActor
class TokenBalanceManager: ObservableObject {
    
    // MARK: - Singleton Instance
    static let shared = TokenBalanceManager()
    
    // MARK: - Published Properties
    @Published private(set) var loadingState: TokenBalanceLoadingState = .idle
    @Published private(set) var lastKnownBalance: TokenBalanceResponse?
    @Published private(set) var lastUpdated: Date?
    
    // MARK: - Private Properties
    private let tokenBalanceService = TokenBalanceService()
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Request Management
    private var currentTask: Task<Void, Never>?
    private var isInitialized = false
    
    // MARK: - Computed Properties
    
    /// Current token balance response (nil if not loaded)
    var tokenBalance: TokenBalanceResponse? {
        if let balance = loadingState.tokenBalance {
            return balance
        }
        return lastKnownBalance
    }
    
    /// Current total tokens available
    var totalTokens: Int {
        return tokenBalance?.totalTokens ?? 0
    }
    
    /// Current user permissions
    var permissions: UserPermissions? {
        return tokenBalance?.permissions
    }
    
    /// Whether user has any tokens available
    var hasTokens: Bool {
        return totalTokens > 0
    }
    
    /// Whether user can generate content
    var canGenerate: Bool {
        return hasTokens
    }
    
    /// Current plan display name
    var planName: String {
        return permissions?.planName ?? "Free"
    }
    
    /// Current account type
    var accountType: String {
        return permissions?.accountType ?? "free"
    }
    
    /// Whether the user has premium features
    var hasPremiumFeatures: Bool {
        guard let permissions = permissions else { return false }
        return permissions.hasQualitySelector || permissions.hasModelSelector
    }

    /// Is currently loading token balance
    var isLoading: Bool {
        return loadingState.isLoading
    }
    
    /// Current error state
    var error: TokenBalanceError? {
        return loadingState.error
    }
    
    // MARK: - Initialization
    private init() {
        print("🏁 TokenBalanceManager: Initializing global token balance manager")
        
        // Set up automatic refresh timer (every 5 minutes)
        setupAutoRefresh()
    }
    
    // MARK: - Public Methods
    
    /// Load token balance for the first time
    func initialize() async {
        print("🚀 TokenBalanceManager: Initializing token balance data")
        
        // Prevent multiple initializations
        guard !isInitialized else {
            print("⏭️ TokenBalanceManager: Already initialized, skipping")
            return
        }
        
        isInitialized = true
        await fetchTokenBalance()

        // If the initial fetch failed, allow re-initialization later
        if case .error = loadingState {
            isInitialized = false
        }
    }
    
    /// Fetch current token balance from API
    func fetchTokenBalance() async {
        // Cancel any existing request to prevent overlapping
        currentTask?.cancel()
        
        // Create new request task
        currentTask = Task { @MainActor in
            // Double-check if we should proceed (task might have been cancelled)
            guard !Task.isCancelled else {
                print("🚫 TokenBalanceManager: Request cancelled before starting")
                return
            }
            
            // Prevent multiple simultaneous requests
            if isLoading {
                print("⏳ TokenBalanceManager: Already loading, skipping duplicate request")
                return
            }
            
            print("🔄 TokenBalanceManager: Fetching token balance")
            loadingState = .loading
            
            do {
                let balance = try await tokenBalanceService.fetchTokenBalance()
                
                // Check if task was cancelled during the request
                guard !Task.isCancelled else {
                    print("🚫 TokenBalanceManager: Request cancelled during execution")
                    return
                }
                
                loadingState = .loaded(balance)
                lastKnownBalance = balance
                lastUpdated = Date()
                
                print("✅ TokenBalanceManager: Successfully loaded token balance")
                print("🎯 TokenBalanceManager: \(balance.totalTokens) tokens available")
                
            } catch let error as TokenBalanceError {
                guard !Task.isCancelled else {
                    print("🚫 TokenBalanceManager: Request cancelled during error handling")
                    return
                }
                
                loadingState = .error(error)
                print("❌ TokenBalanceManager: Failed to fetch token balance: \(error.errorDescription ?? "Unknown error")")
                
            } catch {
                guard !Task.isCancelled else {
                    print("🚫 TokenBalanceManager: Request cancelled during error handling")
                    return
                }
                
                let tokenError = TokenBalanceError.networkError(error)
                loadingState = .error(tokenError)
                print("❌ TokenBalanceManager: Unexpected error: \(error)")
            }
        }
        
        // Wait for the task to complete
        await currentTask?.value
    }
    
    /// Refresh token balance (force update)
    func refresh() async {
        print("🔄 TokenBalanceManager: Forcing token balance refresh")
        await fetchTokenBalance()
    }
    
    /// Silently refresh token balance without showing loading states
    /// Used for background updates when navigating to Art tab
    func refreshSilently() async {
        print("🔕 TokenBalanceManager: Silently refreshing token balance")
        
        // Cancel any existing request to prevent overlapping
        currentTask?.cancel()
        
        // Create silent refresh task that doesn't update loading state
        currentTask = Task { @MainActor in
            guard !Task.isCancelled else {
                print("🚫 TokenBalanceManager: Silent refresh cancelled")
                return
            }
            
            // Don't set loading state for silent refresh
            do {
                print("🔍 TokenBalanceManager: Fetching token balance silently...")
                let tokenBalance = try await tokenBalanceService.fetchTokenBalance()
                
                // Only update if we successfully got data
                loadingState = .loaded(tokenBalance)
                lastKnownBalance = tokenBalance
                lastUpdated = Date()
                
                print("✅ TokenBalanceManager: Silent refresh successful")
                print("💰 TokenBalanceManager: Total tokens: \(tokenBalance.totalTokens)")
                
            } catch {
                print("❌ TokenBalanceManager: Silent refresh failed - \(error)")
                
                // For silent refresh, don't override good data with errors
                // Only set error state if we don't have any data
                if case .idle = loadingState {
                loadingState = .error(error as? TokenBalanceError ?? .specificError("Silent refresh failed"))
            }
        }
        }
        
        await currentTask?.value
    }
    
    /// Check if user can afford a generation
    /// - Parameter cost: Token cost (default: 1)
    /// - Returns: Boolean indicating if user has sufficient tokens
    func canAffordGeneration(cost: Int = 1) -> Bool {
        return totalTokens >= cost
    }
    
    /// Deduct tokens after successful generation (optimistic update)
    /// - Parameter cost: Tokens to deduct
    func deductTokens(_ cost: Int) {
        guard let balance = tokenBalance else {
            print("⚠️ TokenBalanceManager: Cannot deduct tokens - no balance loaded")
            return
        }
        
        let newTotal = max(0, balance.totalTokens - cost)
        print("💳 TokenBalanceManager: Deducting \(cost) tokens (\(balance.totalTokens) → \(newTotal))")
        
        // Create updated balance with new token count
        // Use a simple JSON reconstruction approach
        let balanceDict: [String: Any] = [
            "subscriptionTokens": max(0, balance.subscriptionTokens - min(cost, balance.subscriptionTokens)),
            "purchasedTokens": max(0, balance.purchasedTokens - max(0, cost - balance.subscriptionTokens)),
            "totalTokens": newTotal,
            "lastSubscriptionRefresh": balance.lastSubscriptionRefresh as Any,
            "maxRollover": balance.maxRollover,
            "currentPlan": balance.currentPlan,
            "permissions": [
                "hasQualitySelector": balance.permissions.hasQualitySelector,
                "hasModelSelector": balance.permissions.hasModelSelector,
                "hasCommercialLicense": balance.permissions.hasCommercialLicense,
                "hasImageUpload": balance.permissions.hasImageUpload,
                "maxFamilyProfiles": balance.permissions.maxFamilyProfiles,
                "maxImagesPerGeneration": balance.permissions.maxImagesPerGeneration,
                "availableModels": balance.permissions.availableModels,
                "availableQuality": balance.permissions.availableQuality,
                "accountType": balance.permissions.accountType,
                "planName": balance.permissions.planName,
                "isTrialing": balance.permissions.isTrialing,
                "trialEndsAt": balance.permissions.trialEndsAt as Any,
                "limitations": [
                    "message": balance.permissions.effectiveLimitations.message,
                    "modelRestriction": balance.permissions.effectiveLimitations.modelRestriction,
                    "qualityRestriction": balance.permissions.effectiveLimitations.qualityRestriction,
                    "upgradeMessage": balance.permissions.effectiveLimitations.upgradeMessage
                ]
            ]
        ]
        
        let jsonData = try! JSONSerialization.data(withJSONObject: balanceDict)
        let updatedBalance = try! JSONDecoder().decode(TokenBalanceResponse.self, from: jsonData)
        
        loadingState = .loaded(updatedBalance)
        
        // Schedule a background refresh to sync with server (with debouncing)
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
            
            // Only refresh if no other requests are active
            guard currentTask == nil || currentTask?.isCancelled == true else {
                print("🔄 TokenBalanceManager: Skipping background sync - request already active")
                return
            }
            
            await fetchTokenBalance()
        }
    }
    
    /// Clear token balance state (on logout)
    func clearState() {
        print("🧹 TokenBalanceManager: Clearing token balance state")
        
        // Cancel any active requests
        currentTask?.cancel()
        currentTask = nil
        
        // Reset state
        loadingState = .idle
        lastKnownBalance = nil
        lastUpdated = nil
        isInitialized = false
        
        stopAutoRefresh()
    }
    
    /// Check if permissions allow a specific feature
    /// - Parameter feature: Feature to check (quality, model, etc.)
    /// - Returns: Boolean indicating feature availability
    func hasPermission(for feature: TokenFeature) -> Bool {
        guard let permissions = permissions else { return false }
        
        switch feature {
        case .qualitySelector:
            return permissions.hasQualitySelector
        case .modelSelector:
            return permissions.hasModelSelector
        case .commercialLicense:
            return permissions.hasCommercialLicense
        case .imageUpload:
            return permissions.hasImageUpload
        case .multipleImages(let count):
            return count <= permissions.maxImagesPerGeneration
        case .familyProfiles(let count):
            return count <= permissions.maxFamilyProfiles
        }
    }
    
    // MARK: - Auto Refresh Management
    
    private func setupAutoRefresh() {
        // Refresh every 5 minutes when app is active
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                // Only auto-refresh if we have data, no error, and no active requests
                if case .loaded = self.loadingState,
                   self.currentTask == nil || self.currentTask?.isCancelled == true {
                    print("⏰ TokenBalanceManager: Auto-refresh timer triggered")
                    await self.fetchTokenBalance()
                } else {
                    print("⏰ TokenBalanceManager: Auto-refresh skipped - request already active or not loaded")
                }
            }
        }
    }
    
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Token Features Enumeration
enum TokenFeature {
    case qualitySelector
    case modelSelector
    case commercialLicense
    case imageUpload
    case multipleImages(count: Int)
    case familyProfiles(count: Int)
}

// MARK: - SwiftUI Environment Integration
struct TokenBalanceManagerKey: EnvironmentKey {
    static let defaultValue = TokenBalanceManager.shared
}

extension EnvironmentValues {
    var tokenBalanceManager: TokenBalanceManager {
        get { self[TokenBalanceManagerKey.self] }
        set { self[TokenBalanceManagerKey.self] = newValue }
    }
}
