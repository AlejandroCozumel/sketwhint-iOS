import SwiftUI

struct AppCoordinator: View {
    @StateObject private var authService = AuthService.shared
    @StateObject private var profileService = ProfileService.shared
    @StateObject private var tokenBalanceManager = TokenBalanceManager.shared
    @State private var isCheckingAuth = true
    
    // Global profile selection state
    @State private var showingProfileCreation = false
    @State private var showingPINEntry = false
    @State private var profileToSelect: FamilyProfile? {
        didSet {
            #if DEBUG
            print("🔄 DEBUG: Global profileToSelect changed from \(oldValue?.name ?? "nil") to \(profileToSelect?.name ?? "nil")")
            #endif
        }
    }
    
    var body: some View {
        Group {
            if isCheckingAuth {
                // Loading screen while checking authentication
                SplashView()
            } else if !authService.isAuthenticated {
                // User not logged in - show login
                NavigationView {
                    LoginView()
                }
            } else if !profileService.hasSelectedProfile || profileService.currentProfile == nil {
                // User authenticated but no profile selected OR profile couldn't be restored - FORCE profile selection
                #if DEBUG
                let _ = print("🔒 DEBUG: No profile selected or profile couldn't be restored, showing ProfileSelectionRequiredView")
                let _ = print("🔒 DEBUG: hasSelectedProfile: \(profileService.hasSelectedProfile)")
                let _ = print("🔒 DEBUG: currentProfile: \(profileService.currentProfile?.name ?? "nil")")
                let _ = print("🔒 DEBUG: Available profiles count: \(profileService.availableProfiles.count)")
                #endif
                ProfileSelectionRequiredView(
                    onProfileSelection: { profile in
                        #if DEBUG
                        print("🎯 DEBUG: Profile selected from view: \(profile.name), hasPin: \(profile.hasPin)")
                        #endif
                        profileToSelect = profile
                        
                        if profile.hasPin {
                            #if DEBUG
                            print("🔐 DEBUG: Profile has PIN, showing PIN entry")
                            #endif
                            showingPINEntry = true
                        } else {
                            #if DEBUG
                            print("👤 DEBUG: Profile has no PIN, selecting directly")
                            #endif
                            Task {
                                await selectProfile(profile, pin: nil)
                            }
                        }
                    },
                    onShowCreateProfile: {
                        #if DEBUG
                        print("➕ DEBUG: Showing create profile")
                        #endif
                        showingProfileCreation = true
                    }
                )
            } else {
                // User authenticated AND has selected profile - show main app
                MainAppView()
                    .environmentObject(tokenBalanceManager)
            }
        }
        .onAppear {
            Task {
                await checkAuthenticationStatus()
            }
        }
        .sheet(isPresented: $showingProfileCreation) {
            CreateProfileView(
                maxProfiles: 5,
                isFirstProfile: true,  // AppCoordinator only shows this when no profiles exist
                onProfileCreated: { newProfile in
                    #if DEBUG
                    print("🎯 DEBUG: Profile created at AppCoordinator level - Name: \(newProfile.name), HasPin: \(newProfile.hasPin)")
                    #endif
                    profileToSelect = newProfile
                    
                    if newProfile.hasPin {
                        showingPINEntry = true
                    } else {
                        // For profiles without PIN, select immediately
                        Task {
                            await selectProfile(newProfile, pin: nil)
                        }
                    }
                }
            )
        }
        .sheet(isPresented: $showingPINEntry) {
            if let profile = profileToSelect {
                #if DEBUG
                let _ = print("🔐 DEBUG: Showing PIN entry for profile: \(profile.name)")
                #endif
                PINEntryView(
                    profile: profile,
                    onPINVerified: { verifiedProfile, pin in
                        Task {
                            await selectProfile(verifiedProfile, pin: pin)
                        }
                    },
                    onCancel: {
                        showingPINEntry = false
                        profileToSelect = nil
                    }
                )
            } else {
                #if DEBUG
                let _ = print("❌ DEBUG: profileToSelect is nil in PIN entry sheet!")
                #endif
                Text("Error: No profile selected for PIN entry")
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .interactiveDismissDisabled($showingPINEntry.wrappedValue) // Prevent swipe-to-dismiss for PIN entry
    }
    
    private func checkAuthenticationStatus() async {
        await authService.checkAuthenticationStatus()
        
        // If authenticated, properly load and validate stored profile
        if authService.isAuthenticated {
            await loadStoredProfile()
            
            // Initialize token balance after authentication
            Task {
                await tokenBalanceManager.initialize()
            }
        } else {
            // Clear token balance state when not authenticated
            tokenBalanceManager.clearState()
        }
        
        // Add a small delay for smooth transition
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            isCheckingAuth = false
        }
    }
    
    /// Load and validate stored profile on app startup
    private func loadStoredProfile() async {
        do {
            // First, load all available profiles from API
            let profiles = try await profileService.loadFamilyProfiles()
            
            // Then validate and restore stored profile
            await profileService.validateStoredProfile(profiles)
            
            #if DEBUG
            if let currentProfile = profileService.currentProfile {
                print("✅ Profile restored on startup: \(currentProfile.name)")
            } else {
                print("📝 No profile to restore on startup")
            }
            #endif
        } catch {
            #if DEBUG
            print("❌ Error loading stored profile on startup: \(error)")
            #endif
            
            // On error, fallback to checkSelectedProfile behavior
            await profileService.checkSelectedProfile()
        }
    }
    
    private func selectProfile(_ profile: FamilyProfile, pin: String?) async {
        do {
            try await ProfileService.shared.selectProfile(profile, pin: pin)
            
            await MainActor.run {
                showingPINEntry = false
                showingProfileCreation = false
                profileToSelect = nil
            }
        } catch {
            #if DEBUG
            print("❌ DEBUG: Profile selection failed: \(error)")
            #endif
            // Handle error appropriately
        }
    }
}

// MARK: - Splash View
struct SplashView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background using your constants
            AppColors.primaryBlue
                .ignoresSafeArea()
            
            VStack(spacing: AppSpacing.xl) {
                // App logo with animation
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 200, height: 200)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                    
                    Circle()
                        .fill(.white.opacity(0.1))
                        .frame(width: 150, height: 150)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                    
                    Text("🎨")
                        .font(.system(size: 80))
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                }
                
                VStack(spacing: AppSpacing.md) {
                    Text("SketchWink")
                        .font(AppTypography.appTitle)
                        .foregroundColor(.white)
                    
                    Text("AI-Powered Creative Platform for Families")
                        .onboardingBody()
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                    
                    // Loading indicator
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                        .padding(.top, AppSpacing.lg)
                }
            }
            .contentPadding()
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - App Root View (Update your main app)
struct AppRootView: View {
    var body: some View {
        AppCoordinator()
            .preferredColorScheme(.light) // Force light mode for family-friendly appearance
    }
}

// MARK: - Profile Selection Required View

struct ProfileSelectionRequiredView: View {
    @StateObject private var profileService = ProfileService.shared
    @State private var isLoading = true
    @State private var error: Error?
    @State private var showingError = false
    
    // Closures to communicate with AppCoordinator
    let onProfileSelection: (FamilyProfile) -> Void
    let onShowCreateProfile: () -> Void
    
    init(
        onProfileSelection: @escaping (FamilyProfile) -> Void = { _ in },
        onShowCreateProfile: @escaping () -> Void = {}
    ) {
        self.onProfileSelection = onProfileSelection
        self.onShowCreateProfile = onShowCreateProfile
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.xl) {
                if isLoading {
                    #if DEBUG
                    let _ = print("🔄 DEBUG: Showing loading view")
                    #endif
                    loadingView
                } else if profileService.availableProfiles.isEmpty {
                    #if DEBUG
                    let _ = print("➕ DEBUG: Showing create first profile view")
                    #endif
                    createFirstProfileView
                } else {
                    #if DEBUG
                    let _ = print("👥 DEBUG: Showing select profile view with \(profileService.availableProfiles.count) profiles")
                    #endif
                    selectProfileView
                }
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("Family Profile")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(true)
        }
        .task {
            await loadProfiles()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(error?.localizedDescription ?? "An error occurred")
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: AppSpacing.xl) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppColors.primaryBlue)
            
            Text("Loading profiles...")
                .font(AppTypography.bodyLarge)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Create First Profile View
    private var createFirstProfileView: some View {
        VStack(spacing: AppSpacing.xl) {
            // Header
            VStack(spacing: AppSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(AppColors.primaryPink)
                        .frame(width: 120, height: 120)
                        .shadow(
                            color: AppColors.primaryPink.opacity(0.3),
                            radius: AppSizing.shadows.large.radius,
                            x: AppSizing.shadows.large.x,
                            y: AppSizing.shadows.large.y
                        )
                    
                    Text("👨‍👩‍👧‍👦")
                        .font(.system(size: 60))
                }
                
                VStack(spacing: AppSpacing.sm) {
                    Text("Welcome to SketchWink!")
                        .displayMedium()
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("Create your first family profile to start your creative journey")
                        .bodyMedium()
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .contentPadding()
            
            Spacer()
            
            // Create Profile Button
            Button("Create Your First Profile") {
                onShowCreateProfile()
            }
            .largeButtonStyle(backgroundColor: AppColors.primaryPink)
            .childSafeTouchTarget()
            .contentPadding()
        }
    }
    
    // MARK: - Select Profile View
    private var selectProfileView: some View {
        VStack(spacing: AppSpacing.xl) {
            // Header
            VStack(spacing: AppSpacing.lg) {
                Text("Choose Your Profile")
                    .headlineLarge()
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Select a profile to continue")
                    .bodyMedium()
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .contentPadding()
            
            // Profiles Grid - Simplified for debugging
            VStack(spacing: AppSpacing.md) {
                ForEach(profileService.availableProfiles) { profile in
                    Button(action: {
                        #if DEBUG
                        print("🎯 DEBUG: Tapped profile: \(profile.name), hasPin: \(profile.hasPin)")
                        #endif
                        onProfileSelection(profile)
                    }) {
                        HStack {
                            Text(profile.avatar ?? "👤")
                                .font(.system(size: 40))
                            
                            VStack(alignment: .leading) {
                                Text(profile.name)
                                    .font(AppTypography.titleMedium)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text(profile.hasPin ? "🔒 Protected" : "🔓 Open")
                                    .font(AppTypography.captionLarge)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.surfaceLight)
                        .cornerRadius(AppSizing.cornerRadius.md)
                    }
                }
            }
            .contentPadding()
            
            Spacer()
            
            // Create Another Profile Button
            Button("Create Another Profile") {
                onShowCreateProfile()
            }
            .font(AppTypography.titleMedium)
            .foregroundColor(AppColors.primaryBlue)
            .childSafeTouchTarget()
        }
    }
    
    // MARK: - Methods
    private func loadProfiles() async {
        isLoading = true
        
        do {
            let profiles = try await profileService.loadFamilyProfiles()
            
            // Validate stored profile against loaded profiles
            await profileService.validateStoredProfile(profiles)
            
        } catch {
            await MainActor.run {
                self.error = error
                showingError = true
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
}

// MARK: - Preview
#if DEBUG
struct AppCoordinator_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Splash screen
            SplashView()
                .previewDisplayName("Splash Screen")
            
            // Not authenticated
            AppCoordinator()
                .onAppear {
                    AuthService.shared.isAuthenticated = false
                }
                .previewDisplayName("Login Flow")
            
            // Authenticated
            AppCoordinator()
                .onAppear {
                    AuthService.shared.isAuthenticated = true
                    AuthService.shared.currentUser = User(
                        id: "preview_user",
                        email: "demo@sketchwink.com", 
                        name: "Demo User",
                        image: nil,
                        emailVerified: true,
                        createdAt: "2024-01-01T00:00:00.000Z",
                        updatedAt: "2024-01-01T00:00:00.000Z",
                        role: "user",
                        promptEnhancementEnabled: true
                    )
                }
                .previewDisplayName("Main App")
        }
    }
}
#endif