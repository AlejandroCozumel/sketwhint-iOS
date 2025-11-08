import SwiftUI

struct ProfilesView: View {
    @State private var profiles: [FamilyProfile] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var showingError = false
    @State private var showingCreateProfile = false
    @State private var showingEditProfile = false
    @State private var selectedProfile: FamilyProfile?
    @State private var userPermissions: UserPermissions?
    @State private var showingSubscriptionPlans = false
    @State private var highlightedFeature: String?
    @State private var showingMaxProfilesAlert = false
    @State private var showingProfileSelection = false
    @State private var showingAdminOnlyAlert = false
    @State private var profileToSelect: FamilyProfile? {
        didSet {
            // Profile selection changed
        }
    }
    @State private var currentProfile: FamilyProfile?
    @State private var isSwitchingProfile = false
    @State private var showingProfileMenu = false
    @State private var showPainting = false
    @State private var showSettings = false

    @StateObject private var authService = AuthService.shared
    @StateObject private var profileService = ProfileService.shared
    @StateObject private var tokenManager = TokenBalanceManager.shared
    @StateObject private var localization = LocalizationManager.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    iPadTabHeader(
                        profileService: profileService,
                        tokenManager: tokenManager,
                        title: "profiles.title".localized,
                        onProfileTap: { showingProfileMenu = true },
                        onCreditsTap: { /* TODO: Show purchase credits modal */ },
                        onUpgradeTap: { showingSubscriptionPlans = true }
                    )
                }

                ScrollView {
                    VStack(spacing: AppSpacing.sectionSpacing) {
                        if isLoading {
                            loadingView
                        } else if profiles.isEmpty {
                            emptyStateView
                        } else {
                            profileManagementView
                        }
                    }
                    .pageMargins()
                    .padding(.top, AppSpacing.xs)
                    .padding(.bottom, AppSpacing.sectionSpacing)
                }
            }
            .iPadContentPadding()
            .background(AppColors.backgroundLight)
            .navigationTitle(UIDevice.current.userInterfaceIdiom == .pad ? "nav.profiles".localized : "profiles.title".localized)
            .navigationBarTitleDisplayMode(UIDevice.current.userInterfaceIdiom == .pad ? .inline : .large)
            .toolbar {
                if UIDevice.current.userInterfaceIdiom != .pad {
                    AppToolbarContent(
                        profileService: profileService,
                        tokenManager: tokenManager,
                        onProfileTap: { showingProfileMenu = true },
                        onCreditsTap: { /* TODO: Show purchase credits modal */ },
                        onUpgradeTap: { showingSubscriptionPlans = true }
                    )
                }
            }
        }
        .task {
            await loadData()
        }
        .dismissableFullScreenCover(isPresented: $showingProfileMenu) {
            ProfileMenuSheet(
                selectedTab: .constant(4),
                showPainting: $showPainting,
                showSettings: $showSettings
            )
        }
        .dismissableFullScreenCover(isPresented: $showSettings) {
            SettingsView()
        }
        .dismissableFullScreenCover(isPresented: $showPainting) {
            NavigationView {
                PaintingView()
            }
        }
        .onAppear {
            loadCurrentProfile()
        }
        .alert("common.error".localized, isPresented: $showingError) {
            Button("common.ok".localized) { }
        } message: {
            Text(error?.localizedDescription ?? "common.unknown.error".localized)
        }
        .alert("profiles.max.reached.title".localized, isPresented: $showingMaxProfilesAlert) {
            Button("common.ok".localized) { }
        } message: {
            Text(String(format: "profiles.max.reached.message".localized, userPermissions?.maxFamilyProfiles ?? 5))
        }
        .dismissableFullScreenCover(isPresented: $showingCreateProfile) {
            CreateProfileView(
                maxProfiles: userPermissions?.maxFamilyProfiles ?? 1,
                isFirstProfile: profiles.isEmpty,  // Pass if this is the first profile
                onProfileCreated: { newProfile, usedPin in
                    profiles.append(newProfile)
                    // After creating profile, automatically select it
                    Task {
                        await selectNewProfile(newProfile, usedPin: usedPin)
                    }
                }
            )
        }
        .dismissableFullScreenCover(item: $selectedProfile) { selectedProfile in
            EditProfileView(
                profileId: selectedProfile.id,  // Pass ID instead of profile object
                onProfileUpdated: { updatedProfile in
                    if let index = profiles.firstIndex(where: { $0.id == updatedProfile.id }) {
                        #if DEBUG
                        print("🔄 ProfilesView: Updating profile in array")
                        print("   - Profile: \(updatedProfile.name)")
                        print("   - Old canUseCustomContentTypes: \(profiles[index].canUseCustomContentTypes)")
                        print("   - New canUseCustomContentTypes: \(updatedProfile.canUseCustomContentTypes)")
                        #endif
                        profiles[index] = updatedProfile
                        #if DEBUG
                        print("   - Array updated successfully")
                        #endif
                    }

                    // Also refresh the profile data from API to ensure consistency
                    Task {
                        do {
                            #if DEBUG
                            print("🔄 ProfilesView: Refreshing profiles from API after update")
                            #endif
                            let freshProfiles = try await loadProfiles()
                            await MainActor.run {
                                profiles = freshProfiles
                                #if DEBUG
                                print("✅ ProfilesView: Profiles refreshed from API")
                                if let updatedFromAPI = freshProfiles.first(where: { $0.id == updatedProfile.id }) {
                                    print("   - API Profile canUseCustomContentTypes: \(updatedFromAPI.canUseCustomContentTypes)")
                                }
                                #endif
                            }
                        } catch {
                            #if DEBUG
                            print("❌ ProfilesView: Failed to refresh profiles from API: \(error)")
                            #endif
                        }
                    }
                },
                onProfileDeleted: { deletedProfile in
                    profiles.removeAll { $0.id == deletedProfile.id }
                }
            )
        }
        .dismissableFullScreenCover(isPresented: $showingSubscriptionPlans) {
            SubscriptionPlansView()
        }
        .dismissableFullScreenCover(isPresented: $showingProfileSelection) {
            if let profile = profileToSelect {
                ProfileSelectionView(
                    profile: profile,
                    onProfileSelected: { selectedProfile in
                        if selectedProfile.hasPin {
                            // Switch to PIN entry
                            showingProfileSelection = false
                            profileToSelect = selectedProfile
                        } else {
                            Task {
                                await selectProfile(selectedProfile, pin: nil)
                            }
                        }
                    }
                )
            }
        }
        .dismissableFullScreenCover(item: $profileToSelect) { profile in
            #if DEBUG
            let _ = print("📱 ProfilesView: PINEntryView sheet appearing for \(profile.name)")
            #endif
            PINEntryView(
                profile: profile,
                onPINVerified: { verifiedProfile, pin in
                    Task {
                        await switchToProfile(verifiedProfile, pin: pin)
                    }
                },
                onCancel: {
                    profileToSelect = nil
                }
            )
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: AppSpacing.xl) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppColors.primaryBlue)

            Text("profiles.loading".localized)
                .font(AppTypography.bodyLarge)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 200)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
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
                    Text("profiles.create.title".localized)
                        .displayMedium()
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("profiles.create.subtitle".localized)
                        .bodyMedium()
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .contentPadding()

            // Benefits Card
            VStack(spacing: AppSpacing.md) {
                Text("profiles.benefits.title".localized)
                    .headlineMedium()
                    .foregroundColor(AppColors.textPrimary)

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    ProfileBenefitItem(icon: "👶", title: "profiles.benefit.child.safe".localized, description: "profiles.benefit.child.safe.desc".localized)
                    ProfileBenefitItem(icon: "🔒", title: "profiles.benefit.pin.protection".localized, description: "profiles.benefit.pin.protection.desc".localized)
                    ProfileBenefitItem(icon: "🎨", title: "profiles.benefit.personal.collections".localized, description: "profiles.benefit.personal.collections.desc".localized)
                    ProfileBenefitItem(icon: "📊", title: "profiles.benefit.usage.tracking".localized, description: "profiles.benefit.usage.tracking.desc".localized)
                }
            }
            .cardStyle()

            // Create First Profile Button
            Button("profiles.create.first".localized) {
                if canCreateProfile {
                    showingCreateProfile = true
                } else {
                    handleProfileCreationLimit()
                }
            }
            .largeButtonStyle(backgroundColor: AppColors.primaryPink)
        }
    }

    // MARK: - Profile Management View
    private var profileManagementView: some View {
        VStack(spacing: AppSpacing.sectionSpacing) {

            // Combined Plan Information Card
            planInformationCard

            // Profiles Grid
            profilesGrid

            // Add Profile Button
            addProfileButton

            // Account section
            accountSection
        }
    }

    // MARK: - Profile Capacity Card
    private var planInformationCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("profiles.capacity.title".localized)
                .headlineMedium()
                .foregroundColor(AppColors.textPrimary)

            if let permissions = userPermissions {
                ProgressView(value: Double(profiles.count), total: Double(max(permissions.maxFamilyProfiles, 1)))
                    .tint(AppColors.primaryBlue)
                    .scaleEffect(x: 1, y: 1.2, anchor: .center)

                HStack {
                    Text(String(format: "profiles.capacity.used".localized, profiles.count))
                        .captionLarge()
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    Text(String(format: "profiles.capacity.available".localized, max(permissions.maxFamilyProfiles - profiles.count, 0)))
                        .captionLarge()
                        .foregroundColor(AppColors.textSecondary)
                }

                if profiles.count >= permissions.maxFamilyProfiles {
                    Text("profiles.capacity.limit.reached".localized)
                        .captionMedium()
                        .foregroundColor(AppColors.warningOrange)
                }
            } else {
                ProgressView()
                    .tint(AppColors.primaryBlue)
            }
        }
        .contentPadding()
        .frame(maxWidth: .infinity)
        .background(AppColors.surfaceLight)
        .cornerRadius(AppSizing.cornerRadius.lg)
        .shadow(
            color: Color.black.opacity(AppSizing.shadows.small.opacity),
            radius: AppSizing.shadows.small.radius,
            x: AppSizing.shadows.small.x,
            y: AppSizing.shadows.small.y
        )
    }

    // MARK: - Profiles Grid
    private var profilesGrid: some View {
        LazyVGrid(columns: GridLayouts.categoryGrid, spacing: AppSpacing.grid.rowSpacing) {
            ForEach(profiles) { profile in
                ProfileCard(
                    profile: profile,
                    isCurrentProfile: currentProfile?.id == profile.id,
                    isLoading: isSwitchingProfile,
                    canEdit: currentProfile?.isDefault == true,
                    onTap: {
                        let isAlreadySelected = currentProfile?.id == profile.id

                        if isAlreadySelected {
                            #if DEBUG
                            print("   - Current profile tapped again; opening settings for \(profile.name)")
                            #endif
                            selectedProfile = profile
                            profileToSelect = nil
                            return
                        }

                        if profile.hasPin {
                            #if DEBUG
                            print("   - Showing PIN entry for \(profile.name)")
                            #endif
                            profileToSelect = profile
                        } else {
                            #if DEBUG
                            print("   - Switching directly to \(profile.name) (no PIN)")
                            #endif
                            Task {
                                await switchToProfile(profile, pin: nil)
                            }
                        }
                    },
                    onEditTap: {
                        // Edit profile
                        selectedProfile = profile
                        showingEditProfile = true
                    }
                )
            }
        }
    }

    // MARK: - Add Profile Button
    private var addProfileButton: some View {
        VStack(spacing: AppSpacing.sm) {
            Button {
                if canCreateProfile {
                    showingCreateProfile = true
                } else {
                    handleProfileCreationLimit()
                }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: canCreateProfile ? "plus" : (isFreePlan ? "lock.fill" : "exclamationmark.triangle.fill"))

                    Text(canCreateProfile ? "profiles.add.family.profile".localized : (isFreePlan ? "profiles.upgrade.to.add".localized : "profiles.limit.reached".localized))
                }
                .largeButtonStyle(backgroundColor: canCreateProfile ? AppColors.primaryBlue : AppColors.warningOrange)
            }

            if !canCreateProfile && isFreePlan {
                Text("profiles.upgrade.plan".localized)
                    .captionLarge()
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            } else if !canCreateProfile {
                Text("profiles.max.profiles.reached".localized)
                    .captionLarge()
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Account Section
    private var accountSection: some View {
        Group {
            if let user = authService.currentUser {
                Button(action: {
                    showSettings = true
                }) {
                    VStack(spacing: AppSpacing.sm) {
                        HStack(spacing: AppSpacing.md) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.primaryBlue)
                                    .frame(width: 50, height: 50)

                                Text("👤")
                                    .font(.system(size: 24))
                            }

                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text(user.name)
                                    .bodyLarge()
                                    .foregroundColor(AppColors.textPrimary)

                                Text(user.email)
                                    .captionLarge()
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Spacer()

                            if user.emailVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(AppColors.successGreen)
                                    .font(.system(size: 16))
                            }
                        }
                        .contentPadding()
                        .background(AppColors.backgroundLight)
                        .cornerRadius(AppSizing.cornerRadius.md)
                    }
                    .cardStyle()
                }
                .buttonStyle(PlainButtonStyle())
                .childSafeTouchTarget()
            }
        }
    }

    // MARK: - Computed Properties
    private var canCreateProfile: Bool {
        guard let permissions = userPermissions else {
            #if DEBUG
            print("🚨 ProfilesView: userPermissions is nil, denying profile creation")
            #endif
            return false
        }

        let canCreate = profiles.count < permissions.maxFamilyProfiles

        #if DEBUG
        print("🔍 ProfilesView: canCreateProfile check:")
        print("   - Current profiles: \(profiles.count)")
        print("   - Max allowed: \(permissions.maxFamilyProfiles)")
        print("   - Can create: \(canCreate)")
        print("   - Plan: \(permissions.planName)")
        #endif

        return canCreate
    }

    private var isFreePlan: Bool {
        guard let permissions = userPermissions else { return true }
        let isFree = permissions.maxFamilyProfiles <= 1

        #if DEBUG
        print("🔍 ProfilesView: isFreePlan check:")
        print("   - Max profiles: \(permissions.maxFamilyProfiles)")
        print("   - Is free plan: \(isFree)")
        #endif

        return isFree
    }

    // MARK: - Methods
    private func loadData() async {
        isLoading = true

        do {
            // Load both profiles and permissions in parallel
            async let profilesResponse = loadProfiles()
            async let permissionsResponse = loadPermissions()

            let (loadedProfiles, loadedPermissions) = try await (profilesResponse, permissionsResponse)

            await MainActor.run {
                profiles = loadedProfiles
                userPermissions = loadedPermissions
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                showingError = true
                isLoading = false
            }
        }
    }

    private func loadProfiles() async throws -> [FamilyProfile] {
        // Use ProfileService to load family profiles from backend
        return try await ProfileService.shared.loadFamilyProfiles()
    }

    private func loadPermissions() async throws -> UserPermissions {
        // Use GenerationService to get user permissions from /user/token-balance endpoint
        return try await GenerationService.shared.getUserPermissions()
    }

    private func handleProfileCreationLimit() {
        #if DEBUG
        print("🚨 ProfilesView: handleProfileCreationLimit called")
        print("   - isFreePlan: \(isFreePlan)")
        print("   - profiles.count: \(profiles.count)")
        print("   - maxFamilyProfiles: \(userPermissions?.maxFamilyProfiles ?? -1)")
        #endif

        if isFreePlan {
            // Free users: redirect to purchase modal
            #if DEBUG
            print("   - Action: Showing subscription plans for free user")
            #endif
            highlightedFeature = "Family Profiles"
            showingSubscriptionPlans = true
        } else {
            // Paid users: show alert about maximum limit
            #if DEBUG
            print("   - Action: Showing max profiles alert for paid user")
            #endif
            showingMaxProfilesAlert = true
        }
    }

    private func selectProfile(_ profile: FamilyProfile, pin: String?) async {
        // Reuse the unified switching logic so UI state stays consistent
        await switchToProfile(profile, pin: pin)
        await MainActor.run {
            showingProfileSelection = false
        }
    }

    private func switchToProfile(_ profile: FamilyProfile, pin: String?) async {
        await MainActor.run {
            isSwitchingProfile = true
        }

        do {
            // Use ProfileService's selectProfile method (calls API and stores locally)
            try await ProfileService.shared.selectProfile(profile, pin: pin)

            await MainActor.run {
                currentProfile = profile
                isSwitchingProfile = false
                profileToSelect = nil

            }
        } catch {
            await MainActor.run {
                isSwitchingProfile = false
                self.error = error
                showingError = true

                #if DEBUG
                print("Failed to switch profile: \(error)")
                #endif
            }
        }
    }

    private func loadCurrentProfile() {
        // Load current profile from ProfileService
        currentProfile = ProfileService.shared.currentProfile

        #if DEBUG
        print("🔍 ProfilesView: Current profile loaded: \(currentProfile?.name ?? "None")")
        #endif
    }

    private func selectNewProfile(_ profile: FamilyProfile, usedPin: String?) async {
        #if DEBUG
        print("🎯 ProfilesView: Auto-selecting newly created profile: \(profile.name)")
        print("   - Profile has PIN: \(profile.hasPin)")
        print("   - Used PIN: \(usedPin != nil ? "provided" : "none")")
        #endif

        await MainActor.run {
            isSwitchingProfile = true
        }

        do {
            // Use selectProfile which properly handles PIN validation and profile selection
            // This calls the correct /api/profiles/select endpoint
            try await ProfileService.shared.selectProfile(profile, pin: usedPin)

            await MainActor.run {
                currentProfile = profile
                isSwitchingProfile = false

                #if DEBUG
                print("✅ ProfilesView: Successfully auto-selected new profile: \(profile.name)")
                #endif
            }
        } catch {
            await MainActor.run {
                isSwitchingProfile = false
                self.error = error
                showingError = true

                #if DEBUG
                print("❌ ProfilesView: Failed to auto-select new profile: \(error)")
                #endif
            }
        }
    }
}

// MARK: - Supporting Views

struct ProfileBenefitItem: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Text(icon)
                .font(.system(size: AppSizing.iconSizes.lg))

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .titleMedium()
                    .foregroundColor(AppColors.textPrimary)

                Text(description)
                    .captionLarge()
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
    }
}

struct ProfileCard: View {
    let profile: FamilyProfile
    let isCurrentProfile: Bool
    let isLoading: Bool
    let canEdit: Bool
    let onTap: () -> Void
    let onEditTap: () -> Void

    var body: some View {
        // Main profile card
        Button(action: onTap) {
            VStack(spacing: AppSpacing.md) {
                // Avatar Circle
                ZStack {
                        Circle()
                            .fill(Color(hex: profile.profileColor))
                            .frame(width: 80, height: 80)

                        Text(profile.displayAvatar)
                            .font(.system(size: 40))

                        // Loading indicator
                        if isLoading {
                            Circle()
                                .fill(.black.opacity(0.3))
                                .frame(width: 80, height: 80)

                            ProgressView()
                                .scaleEffect(1.2)
                                .tint(.white)
                        }

                        // Current profile indicator
                        if isCurrentProfile {
                            VStack {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                        .background(
                                            Circle()
                                                .fill(AppColors.successGreen)
                                                .frame(width: 28, height: 28)
                                        )
                                    Spacer()
                                }
                                Spacer()
                            }
                            .frame(width: 80, height: 80)
                        }

                        // PIN indicator
                        if profile.hasPin && !isCurrentProfile {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Image(systemName: "lock.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                        .background(
                                            Circle()
                                                .fill(.black.opacity(0.3))
                                                .frame(width: 24, height: 24)
                                        )
                                }
                            }
                            .frame(width: 80, height: 80)
                        }

                        // Edit button overlay - TOP RIGHT (only for admin users)
                        if canEdit {
                            VStack {
                                HStack {
                                    Spacer()
                                    Button(action: onEditTap) {
                                        Image(systemName: "gearshape.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(AppColors.primaryBlue)
                                            .frame(width: 28, height: 28)
                                            .background(.ultraThinMaterial, in: Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(AppColors.primaryBlue.opacity(0.3), lineWidth: 1)
                                            )
                                            .shadow(color: AppColors.primaryBlue.opacity(0.2), radius: 2, x: 0, y: 1)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                Spacer()
                            }
                            .frame(width: 80, height: 80)
                        }
                    }

                    VStack(spacing: AppSpacing.xs) {
                        HStack {
                            Text(profile.name)
                                .font(AppTypography.titleMedium)
                                .foregroundColor(AppColors.textPrimary)
                                .multilineTextAlignment(.center)

                            if profile.isDefault {
                                Text("profiles.main".localized)
                                    .font(AppTypography.captionSmall)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, AppSpacing.xs)
                                    .padding(.vertical, 2)
                                    .background(AppColors.warningOrange)
                                    .cornerRadius(AppSizing.cornerRadius.xs)
                            }
                        }

                        if isCurrentProfile {
                            Text("profiles.active.profile".localized)
                                .font(AppTypography.captionMedium)
                                .foregroundColor(AppColors.successGreen)
                        } else {
                            Text("profiles.tap.to.switch".localized)
                                .font(AppTypography.captionMedium)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .background(
                    isCurrentProfile ? AppColors.successGreen.opacity(0.1) : AppColors.backgroundLight
                )
                .cornerRadius(AppSizing.cornerRadius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                        .stroke(
                            isCurrentProfile ? AppColors.successGreen : AppColors.borderLight,
                            lineWidth: isCurrentProfile ? 2 : 1
                        )
                )
                .shadow(
                    color: isCurrentProfile ? AppColors.successGreen.opacity(0.2) : Color.black.opacity(0.05),
                    radius: isCurrentProfile ? 8 : 4,
                    x: 0,
                    y: isCurrentProfile ? 4 : 2
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isLoading)
            .childSafeTouchTarget()
    }
}

// MARK: - Profile Info Row Component
struct ProfileInfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: AppSizing.iconSizes.md))
                .foregroundColor(AppColors.infoBlue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)

                Text(description)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()
        }
        .padding(AppSpacing.sm)
    }
}

struct PlanInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let current: String

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: AppSizing.iconSizes.md))
                .foregroundColor(AppColors.primaryBlue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)

                Text(current)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Text(value)
                .font(AppTypography.titleMedium)
                .foregroundColor(AppColors.primaryBlue)
        }
        .padding(AppSpacing.sm)
        .background(AppColors.primaryBlue.opacity(0.05))
        .cornerRadius(AppSizing.cornerRadius.sm)
    }
}

// MARK: - Placeholder Views (to be implemented)

struct CreateProfileView: View {
    let maxProfiles: Int
    let isFirstProfile: Bool  // NEW: Indicates if this is the first profile
    let onProfileCreated: (FamilyProfile, String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var profileName = ""
    @State private var selectedAvatar = "👤"
    @State private var enablePin = false
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var canMakePurchases = false  // Will be set to true for first profile in onAppear
    @State private var canUseCustomContent = true
    @State private var isCreating = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private let availableAvatars = [
        // Family members
        "👨", "👩", "👧", "👦", "👶", "👴", "👵",
        // Fun characters
        "🐶", "🐱", "🦄", "🌈", "⭐", "🎨", "📚",
        // More options
        "🚀", "🎮", "🏀", "🎵", "🌸", "🦋", "🐰"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {

                    // Header
                    headerSection

                    // Avatar Selection
                    avatarSelectionSection

                    // Profile Name
                    profileNameSection

                    // PIN Setup
                    pinSetupSection

                    // Parental Controls
                    parentalControlsSection

                    // Create Button
                    createButtonSection
                }
                .pageMargins()
                .padding(.vertical, AppSpacing.sectionSpacing)
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("profiles.create.profile.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(8)
                            .background(AppColors.surfaceLight)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(AppColors.borderLight, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
            }
            .toolbarBackground(AppColors.backgroundLight, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .alert("profiles.error.title".localized, isPresented: $showingError) {
            Button("common.ok".localized) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // For first profile, enforce canMakePurchases = true (non-negotiable)
            if isFirstProfile {
                canMakePurchases = true
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: AppSpacing.lg) {
            // Selected Avatar Preview
            ZStack {
                Circle()
                    .fill(Color(hex: profileColor))
                    .frame(width: 120, height: 120)
                    .shadow(
                        color: Color(hex: profileColor).opacity(0.3),
                        radius: AppSizing.shadows.large.radius,
                        x: AppSizing.shadows.large.x,
                        y: AppSizing.shadows.large.y
                    )

                Text(selectedAvatar)
                    .font(.system(size: 60))

                // PIN indicator preview
                if enablePin {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "lock.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .background(
                                    Circle()
                                        .fill(.black.opacity(0.3))
                                        .frame(width: 32, height: 32)
                                )
                        }
                    }
                    .frame(width: 120, height: 120)
                }
            }

            VStack(spacing: AppSpacing.sm) {
                Text(isFirstProfile ? "profiles.create.your.first".localized : "profiles.create.title".localized)
                    .headlineLarge()
                    .foregroundColor(AppColors.textPrimary)

                if isFirstProfile {
                    VStack(spacing: AppSpacing.xs) {
                        Text("profiles.main.description".localized)
                            .bodyMedium()
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)

                        Text("profiles.main.permissions.manage".localized)
                            .captionLarge()
                            .foregroundColor(AppColors.primaryBlue)
                            .multilineTextAlignment(.center)

                        Text("profiles.main.cannot.delete".localized)
                            .captionLarge()
                            .foregroundColor(AppColors.primaryBlue)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Text("profiles.setup.personalized".localized)
                        .bodyMedium()
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .contentPadding()
    }

    // MARK: - Avatar Selection
    private var avatarSelectionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("profiles.choose.avatar".localized)
                .headlineMedium()
                .foregroundColor(AppColors.textPrimary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: AppSpacing.sm) {
                ForEach(availableAvatars, id: \.self) { avatar in
                    Button {
                        selectedAvatar = avatar
                    } label: {
                        Text(avatar)
                            .font(.system(size: 32))
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(selectedAvatar == avatar ? Color(hex: profileColor).opacity(0.2) : AppColors.backgroundLight)
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        selectedAvatar == avatar ? Color(hex: profileColor) : AppColors.borderLight,
                                        lineWidth: selectedAvatar == avatar ? 3 : 1
                                    )
                            )
                    }
                    .childSafeTouchTarget()
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Profile Name
    private var profileNameSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("profiles.profile.name".localized)
                .headlineMedium()
                .foregroundColor(AppColors.textPrimary)

            TextField("profiles.enter.name.example".localized, text: $profileName)
                .textFieldStyle(PlainTextFieldStyle())
                .font(AppTypography.bodyLarge)
                .padding(AppSpacing.md)
                .background(AppColors.backgroundLight)
                .cornerRadius(AppSizing.cornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                        .stroke(AppColors.borderMedium, lineWidth: 1)
                )
                .autocorrectionDisabled()

            if !profileName.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.successGreen)
                    Text("profiles.name.looks.good".localized)
                        .captionMedium()
                        .foregroundColor(AppColors.successGreen)
                    Spacer()
                }
            }
        }
        .cardStyle()
    }

    // MARK: - PIN Setup
    private var pinSetupSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("profiles.pin.protection".localized)
                    .headlineMedium()
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Toggle("", isOn: $enablePin)
                    .labelsHidden()
                    .tint(AppColors.primaryBlue)
                    .childSafeTouchTarget()
            }

            Text("profiles.pin.description".localized)
                .captionLarge()
                .foregroundColor(AppColors.textSecondary)

            if enablePin {
                VStack(spacing: AppSpacing.md) {
                    // PIN Input
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("profiles.enter.pin".localized)
                            .titleMedium()
                            .foregroundColor(AppColors.textPrimary)

                        SecureField("0000", text: $pin)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(AppTypography.headlineMedium)
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                            .padding(AppSpacing.md)
                            .background(AppColors.backgroundLight)
                            .cornerRadius(AppSizing.cornerRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                                    .stroke(
                                        pin.count == 4 ? AppColors.successGreen : AppColors.borderMedium,
                                        lineWidth: 1
                                    )
                            )
                            .onChange(of: pin) { oldValue, newValue in
                                // Limit to 4 digits
                                if newValue.count > 4 {
                                    pin = String(newValue.prefix(4))
                                }
                            }
                    }

                    // Confirm PIN
                    if pin.count == 4 {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("profiles.confirm.pin".localized)
                                .titleMedium()
                                .foregroundColor(AppColors.textPrimary)

                            SecureField("0000", text: $confirmPin)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(AppTypography.headlineMedium)
                                .multilineTextAlignment(.center)
                                .keyboardType(.numberPad)
                                .padding(AppSpacing.md)
                                .background(AppColors.backgroundLight)
                                .cornerRadius(AppSizing.cornerRadius.md)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                                        .stroke(
                                            confirmPin.count == 4 && confirmPin == pin ? AppColors.successGreen : AppColors.borderMedium,
                                            lineWidth: 1
                                        )
                                )
                                .onChange(of: confirmPin) { oldValue, newValue in
                                    // Limit to 4 digits
                                    if newValue.count > 4 {
                                        confirmPin = String(newValue.prefix(4))
                                    }
                                }
                        }

                        // PIN validation feedback
                        if confirmPin.count == 4 {
                            HStack {
                                Image(systemName: confirmPin == pin ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(confirmPin == pin ? AppColors.successGreen : AppColors.errorRed)

                                Text(confirmPin == pin ? "profiles.pins.match".localized : "profiles.pins.dont.match".localized)
                                    .captionMedium()
                                    .foregroundColor(confirmPin == pin ? AppColors.successGreen : AppColors.errorRed)

                                Spacer()
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .cardStyle()
        .animation(.easeInOut(duration: 0.3), value: enablePin)
    }

    // MARK: - Parental Controls
    private var parentalControlsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("profiles.permissions".localized)
                .headlineMedium()
                .foregroundColor(AppColors.textPrimary)

            VStack(spacing: AppSpacing.md) {
                if isFirstProfile {
                    // First profile: purchases always enabled, show locked state
                    PermissionToggleDisabled(
                        icon: "creditcard.fill",
                        title: "profiles.can.make.purchases".localized,
                        description: "profiles.main.profile.required".localized,
                        isOn: true,
                        color: AppColors.warningOrange,
                        lockedReason: "profiles.main.profile.required".localized
                    )
                } else {
                    // Additional profiles: allow toggle
                    PermissionToggle(
                        icon: "creditcard.fill",
                        title: "profiles.can.make.purchases".localized,
                        description: "profiles.allow.purchases".localized,
                        isOn: $canMakePurchases,
                        color: AppColors.warningOrange
                    )
                }

                PermissionToggle(
                    icon: "photo.fill",
                    title: "profiles.can.use.custom".localized,
                    description: "profiles.allow.custom.images".localized,
                    isOn: $canUseCustomContent,
                    color: AppColors.primaryPurple
                )
            }
        }
        .cardStyle()
    }

    // MARK: - Create Button
    private var createButtonSection: some View {
        VStack(spacing: AppSpacing.md) {
            Button {
                createProfile()
            } label: {
                HStack {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "person.badge.plus")
                    }

                    Text(isCreating ? "profiles.creating.profile".localized : "profiles.create.button".localized)
                }
                .largeButtonStyle(
                    backgroundColor: AppColors.primaryBlue,
                    isDisabled: !canCreateProfile
                )
            }
            .disabled(!canCreateProfile || isCreating)

            if !canCreateProfile {
                Text("profiles.fill.all.fields".localized)
                    .captionMedium()
                    .foregroundColor(AppColors.errorRed)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Computed Properties
    private var profileColor: String {
        let colors = ["#37B6F6", "#882FF6", "#FF6B9D", "#10B981", "#F97316"]
        let index = abs(profileName.hashValue) % colors.count
        return colors[index]
    }

    private var canCreateProfile: Bool {
        let nameValid = !profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let pinValid = !enablePin || (pin.count == 4 && confirmPin == pin)
        return nameValid && pinValid
    }

    // MARK: - Methods
    private func createProfile() {
        guard canCreateProfile else { return }

        // Additional safety check: prevent creating more than maxProfiles
        // This should never happen if the parent UI is working correctly, but add as safety
        if !isFirstProfile && maxProfiles <= 1 {
            #if DEBUG
            print("🚨 CreateProfileView: Attempted to create additional profile on plan with maxProfiles=\(maxProfiles)")
            #endif
            errorMessage = "Your current plan only allows 1 family profile. Please upgrade to create additional profiles."
            showingError = true
            return
        }

        #if DEBUG
        print("🎯 CreateProfileView: Creating profile")
        print("   - maxProfiles: \(maxProfiles)")
        print("   - isFirstProfile: \(isFirstProfile)")
        #endif

        isCreating = true

        Task {
            do {
                let request = CreateProfileRequest(
                    name: profileName.trimmingCharacters(in: .whitespacesAndNewlines),
                    avatar: selectedAvatar,
                    pin: enablePin ? pin : nil,
                    canMakePurchases: canMakePurchases,
                    canUseCustomContentTypes: canUseCustomContent
                )

                let newProfile = try await ProfileService.shared.createFamilyProfile(request)

                await MainActor.run {
                    // Pass the profile and the PIN that was used (if any)
                    onProfileCreated(newProfile, enablePin ? pin : nil)
                    isCreating = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

struct PermissionToggle: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool
    let color: Color

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: AppSizing.iconSizes.md))
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)

                Text(description)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(color)
                .childSafeTouchTarget()
        }
        .padding(AppSpacing.sm)
        .background(color.opacity(0.05))
        .cornerRadius(AppSizing.cornerRadius.sm)
    }
}

struct PermissionToggleDisabled: View {
    let icon: String
    let title: String
    let description: String
    let isOn: Bool
    let color: Color
    let lockedReason: String

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: AppSizing.iconSizes.md))
                .foregroundColor(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text(title)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                }

                Text(description)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)

                Text(lockedReason)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.primaryBlue)
                    .italic()
            }

            Spacer()

            // Disabled toggle showing locked state
            Toggle("", isOn: .constant(isOn))
                .labelsHidden()
                .tint(color)
                .disabled(true)
                .childSafeTouchTarget()
        }
        .padding(AppSpacing.sm)
        .background(color.opacity(0.05))
        .cornerRadius(AppSizing.cornerRadius.sm)
        .opacity(0.8) // Slightly dimmed to show it's locked
    }
}

struct EditProfileView: View {
    let profileId: String
    let onProfileUpdated: (FamilyProfile) -> Void
    let onProfileDeleted: (FamilyProfile) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileService = ProfileService.shared

    @State private var profile: FamilyProfile?
    @State private var isLoadingProfile = false

    @State private var showingDeleteAlert = false
    @State private var showingCannotDeleteAlert = false
    @State private var showingSuccessAlert = false
    @State private var isDeleting = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var showingError = false

    // Profile permission states
    @State private var canMakePurchases = false
    @State private var canUseCustomContentTypes = false
    @State private var isUpdatingPermissions = false

    // PIN management states
    @State private var pinEnabled = false
    @State private var originalPinEnabled = false
    @State private var newPin = ""
    @State private var confirmNewPin = ""
    @State private var isUpdatingPin = false
    @State private var showPinEditor = false
    @State private var pinAlertTitle = ""
    @State private var pinAlertMessage = ""
    @State private var showingPinAlert = false

    // Admin access control
    private var isCurrentProfileAdmin: Bool {
        profileService.currentProfile?.isDefault == true
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoadingProfile {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("profiles.loading.profile".localized)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.top, AppSpacing.sm)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let profile = profile {
                    ScrollView {
                        VStack(spacing: AppSpacing.sectionSpacing) {
                            // Profile Header
                            profileHeaderSection

                            // Profile Actions
                            profileActionsSection

                            // PIN Management
                            pinManagementSection

                            // Profile Management Info
                            profileManagementInfoSection

                            // Delete Section (conditional)
                            if profile.isDefault == false {
                                deleteProfileSection
                            } else {
                                cannotDeleteSection
                            }
                        }
                        .pageMargins()
                        .padding(.vertical, AppSpacing.sectionSpacing)
                    }
                } else {
                    VStack {
                        Text("profiles.not.found".localized)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.errorRed)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("profiles.edit.profile.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(8)
                            .background(AppColors.surfaceLight)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(AppColors.borderLight, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
            }
            .toolbarBackground(AppColors.backgroundLight, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .alert("profiles.delete.profile.question".localized, isPresented: $showingDeleteAlert) {
            Button("common.cancel".localized, role: .cancel) { }
            Button("profiles.confirm.delete.button".localized, role: .destructive) {
                deleteProfile()
            }
        } message: {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("profiles.delete.confirm".localized)
                Text("profiles.delete.warning".localized)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .alert("profiles.cannot.delete.profile".localized, isPresented: $showingCannotDeleteAlert) {
            Button("common.ok".localized) { }
        } message: {
            Text("profiles.main.cannot.delete.message".localized)
        }
        .alert("profiles.error.title".localized, isPresented: $showingError) {
            Button("common.ok".localized) { }
        } message: {
            Text(errorMessage)
        }
        .alert(pinAlertTitle, isPresented: $showingPinAlert) {
            Button("common.ok".localized) { }
        } message: {
            Text(pinAlertMessage)
        }
        .alert("profiles.deleted.title".localized, isPresented: $showingSuccessAlert) {
            Button("common.ok".localized) {
                dismiss()
            }
        } message: {
            Text(successMessage)
        }
        .onAppear {
            loadCurrentProfile()
        }
    }

    // MARK: - Profile Loading
    private func loadCurrentProfile() {
        isLoadingProfile = true

        Task {
            do {
                #if DEBUG
                print("🔄 EditProfileView: Loading fresh profile data from API")
                print("   - Profile ID: \(profileId)")
                #endif

                // Fetch fresh profiles from API
                let profiles = try await ProfileService.shared.loadFamilyProfiles()

                await MainActor.run {
                    if let freshProfile = profiles.first(where: { $0.id == profileId }) {
                        #if DEBUG
                        print("✅ EditProfileView: Loaded fresh profile from API")
                        print("   - Profile: \(freshProfile.name)")
                        print("   - canMakePurchases: \(freshProfile.canMakePurchases)")
                        print("   - canUseCustomContentTypes: \(freshProfile.canUseCustomContentTypes)")
                        #endif

                        profile = freshProfile
                        canMakePurchases = freshProfile.canMakePurchases
                        canUseCustomContentTypes = freshProfile.canUseCustomContentTypes
                        pinEnabled = freshProfile.hasPin
                        originalPinEnabled = freshProfile.hasPin
                        newPin = ""
                        confirmNewPin = ""
                        showPinEditor = false

                        #if DEBUG
                        print("   - State initialized with fresh data")
                        #endif
                    } else {
                        #if DEBUG
                        print("❌ EditProfileView: Profile not found in API response")
                        #endif
                        profile = nil
                    }
                    isLoadingProfile = false
                }
            } catch {
                #if DEBUG
                print("❌ EditProfileView: Failed to load profile: \(error)")
                #endif
                await MainActor.run {
                    isLoadingProfile = false
                }
            }
        }
    }

    // MARK: - Profile Header
    private var profileHeaderSection: some View {
        VStack(spacing: AppSpacing.lg) {
            ZStack {
                Circle()
                    .fill(Color(hex: profile?.profileColor ?? "#6B7280"))
                    .frame(width: 120, height: 120)
                    .shadow(
                        color: Color(hex: profile?.profileColor ?? "#6B7280").opacity(0.3),
                        radius: AppSizing.shadows.large.radius,
                        x: AppSizing.shadows.large.x,
                        y: AppSizing.shadows.large.y
                    )

                Text(profile?.displayAvatar ?? "👤")
                    .font(.system(size: 60))

                // Default profile badge
                if profile?.isDefault == true {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "crown.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .background(
                                    Circle()
                                        .fill(AppColors.warningOrange)
                                        .frame(width: 32, height: 32)
                                )
                        }
                        Spacer()
                    }
                    .frame(width: 120, height: 120)
                }
            }

            VStack(spacing: AppSpacing.sm) {
                HStack {
                    Text(profile?.name ?? "Profile")
                        .headlineLarge()
                        .foregroundColor(AppColors.textPrimary)

                    if profile?.isDefault == true {
                        Text("profiles.main".localized)
                            .captionMedium()
                            .foregroundColor(.white)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.xs)
                            .background(AppColors.warningOrange)
                            .cornerRadius(AppSizing.cornerRadius.sm)
                    }
                }

                if profile?.isDefault == true {
                    Text("profiles.main.admin.desc".localized)
                        .bodyMedium()
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("profiles.family.member.desc".localized)
                        .bodyMedium()
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .contentPadding()
    }

    // MARK: - Profile Actions
    private var profileActionsSection: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                Text("profiles.permissions".localized)
                    .headlineMedium()
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                if !isCurrentProfileAdmin {
                    Image(systemName: "lock.fill")
                        .foregroundColor(AppColors.textSecondary)
                        .font(.system(size: 16))
                }
            }

            if isCurrentProfileAdmin {
                VStack(spacing: AppSpacing.md) {
                    if profile?.isDefault == true {
                        // Main profile: purchases always enabled, show locked state
                        PermissionToggleDisabled(
                            icon: "creditcard.fill",
                            title: "profiles.can.make.purchases".localized,
                            description: "profiles.main.profile.required".localized,
                            isOn: true,
                            color: AppColors.warningOrange,
                            lockedReason: "profiles.main.profile.required".localized
                        )
                    } else {
                        // Additional profiles: allow toggle
                        PermissionToggle(
                            icon: "creditcard.fill",
                            title: "profiles.can.make.purchases".localized,
                            description: "profiles.allow.purchases".localized,
                            isOn: $canMakePurchases,
                            color: AppColors.warningOrange
                        )
                        .disabled(isUpdatingPermissions)
                        .onChange(of: canMakePurchases) { oldValue, newValue in
                            #if DEBUG
                            print("🎛️ Can Make Purchases toggle changed: \(oldValue) → \(newValue)")
                            #endif
                            if !isUpdatingPermissions {
                                updatePermissions()
                            }
                        }
                    }

                    PermissionToggle(
                        icon: "photo.fill",
                        title: "profiles.can.use.custom".localized,
                        description: "profiles.allow.custom.images".localized,
                        isOn: $canUseCustomContentTypes,
                        color: AppColors.primaryPurple
                    )
                    .disabled(isUpdatingPermissions)
                    .onChange(of: canUseCustomContentTypes) { oldValue, newValue in
                        #if DEBUG
                        print("🎛️ Can Use Custom Content toggle changed: \(oldValue) → \(newValue)")
                        #endif
                        if !isUpdatingPermissions {
                            updatePermissions()
                        }
                    }
                }
            } else {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 32))
                        .foregroundColor(AppColors.textSecondary)

                    Text("profiles.admin.access.required".localized)
                        .titleMedium()
                        .foregroundColor(AppColors.textSecondary)

                    Text("profiles.admin.access.message".localized)
                        .bodyMedium()
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(AppSpacing.lg)
            }
        }
        .cardStyle()
    }

    // MARK: - PIN Management
    private var pinManagementSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Text("profiles.pin.protection".localized)
                    .headlineMedium()
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                let statusText = pinEnabled ? "profiles.enabled".localized : "profiles.disabled".localized
                let statusIcon = pinEnabled ? "lock.fill" : "lock.open.fill"
                Label(statusText, systemImage: statusIcon)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(pinEnabled ? AppColors.primaryBlue : AppColors.textSecondary)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, AppSpacing.xxs)
                    .background(
                        Capsule()
                            .fill(pinEnabled ? AppColors.primaryBlue.opacity(0.12) : AppColors.borderLight.opacity(0.3))
                    )
            }

            if isCurrentProfileAdmin {
                Toggle(isOn: $pinEnabled) {
                    Text("profiles.require.4digit.pin".localized)
                        .bodyMedium()
                        .foregroundColor(AppColors.textPrimary)
                }
                .tint(AppColors.primaryBlue)
                .onChange(of: pinEnabled) { _, newValue in
                    newPin = ""
                    confirmNewPin = ""

                    if newValue {
                        showPinEditor = !originalPinEnabled
                    } else {
                        showPinEditor = false
                    }
                }

                Text("profiles.pin.protect.message".localized)
                    .captionLarge()
                    .foregroundColor(AppColors.textSecondary)

                if pinEnabled && originalPinEnabled && !showPinEditor {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("profiles.pin.protects.profile".localized)
                            .captionMedium()
                            .foregroundColor(AppColors.textSecondary)

                        Button {
                            withAnimation {
                                newPin = ""
                                confirmNewPin = ""
                                showPinEditor = true
                            }
                        } label: {
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: "lock.rotation")
                                Text("profiles.update.pin".localized)
                            }
                            .largeButtonStyle(
                                backgroundColor: AppColors.primaryBlue,
                                foregroundColor: .white,
                                isDisabled: false
                            )
                        }

                        Text("profiles.turn.off.to.remove.pin".localized)
                            .captionMedium()
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .transition(.opacity)
                }

                if pinEnabled && showPinEditor {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(originalPinEnabled ? "profiles.enter.new.pin".localized : "profiles.create.4digit.pin".localized)
                            .captionMedium()
                            .foregroundColor(AppColors.textSecondary)

                        SecureField("profiles.pin.placeholder.0000".localized, text: $newPin)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(AppTypography.headlineMedium)
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                            .padding(AppSpacing.md)
                            .background(AppColors.backgroundLight)
                            .cornerRadius(AppSizing.cornerRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                                    .stroke(
                                        newPin.count == 4 ? AppColors.successGreen : AppColors.borderMedium,
                                        lineWidth: 1
                                    )
                            )
                            .onChange(of: newPin) { _, newValue in
                                let digitsOnly = newValue.filter { $0.isNumber }
                                let limited = String(digitsOnly.prefix(4))
                                if newValue != limited {
                                    newPin = limited
                                }
                                if newPin.count < confirmNewPin.count {
                                    confirmNewPin = String(confirmNewPin.prefix(newPin.count))
                                }
                            }

                        if newPin.count == 4 {
                            SecureField("profiles.confirm.pin.placeholder".localized, text: $confirmNewPin)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(AppTypography.headlineMedium)
                                .multilineTextAlignment(.center)
                                .keyboardType(.numberPad)
                                .padding(AppSpacing.md)
                                .background(AppColors.backgroundLight)
                                .cornerRadius(AppSizing.cornerRadius.md)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                                        .stroke(
                                            confirmNewPin.count == 4 && confirmNewPin == newPin ? AppColors.successGreen : AppColors.borderMedium,
                                            lineWidth: 1
                                        )
                                )
                                .onChange(of: confirmNewPin) { _, newValue in
                                    let digitsOnly = newValue.filter { $0.isNumber }
                                    let allowedLength = min(newPin.count, 4)
                                    let limited = String(digitsOnly.prefix(allowedLength))
                                    if newValue != limited {
                                        confirmNewPin = limited
                                    }
                                }

                            if confirmNewPin.count == 4 {
                                HStack(spacing: AppSpacing.xs) {
                                    Image(systemName: confirmNewPin == newPin ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(confirmNewPin == newPin ? AppColors.successGreen : AppColors.errorRed)

                                    Text(confirmNewPin == newPin ? "profiles.pins.match.check".localized : "profiles.pins.dont.match.check".localized)
                                        .captionMedium()
                                        .foregroundColor(confirmNewPin == newPin ? AppColors.successGreen : AppColors.errorRed)

                                    Spacer()
                                }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else if !pinEnabled && originalPinEnabled {
                    Text("profiles.save.to.remove.pin".localized)
                        .captionMedium()
                        .foregroundColor(AppColors.warningOrange)
                }

                if (pinEnabled && showPinEditor) || (!pinEnabled && originalPinEnabled) {
                    Button(action: updatePinSettings) {
                        HStack {
                            if isUpdatingPin {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: pinEnabled ? "lock.rotation" : "lock.open")
                            }

                            Text(pinActionButtonTitle)
                        }
                        .largeButtonStyle(
                            backgroundColor: pinEnabled ? AppColors.primaryBlue : AppColors.errorRed,
                            isDisabled: !canSavePinSettings || isUpdatingPin
                        )
                    }
                    .disabled(!canSavePinSettings || isUpdatingPin)
                }

                if pinSettingsDirty {
                    Text("profiles.save.pin.changes".localized)
                        .captionMedium()
                        .foregroundColor(AppColors.primaryBlue)
                }

                if pinEnabled {
                    if showPinEditor {
                        Text("profiles.pin.must.be.4".localized)
                            .captionMedium()
                            .foregroundColor(AppColors.textSecondary)
                    } else if originalPinEnabled {
                        Text("profiles.choose.update.or.remove".localized)
                            .captionMedium()
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                else if originalPinEnabled {
                    Text("profiles.reenable.toggle.anytime".localized)
                        .captionMedium()
                        .foregroundColor(AppColors.textSecondary)
                }
            } else {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 32))
                        .foregroundColor(AppColors.textSecondary)

                    Text("profiles.admin.access.required".localized)
                        .titleMedium()
                        .foregroundColor(AppColors.textSecondary)

                    Text("profiles.switch.main.to.manage".localized)
                        .bodyMedium()
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(AppSpacing.lg)
            }
        }
        .cardStyle()
        .animation(.easeInOut, value: showPinEditor)
    }

    private var pinSettingsDirty: Bool {
        if pinEnabled != originalPinEnabled {
            return true
        }

        if pinEnabled && newPin.count == 4 && newPin == confirmNewPin {
            return true
        }

        return false
    }

    private var canSavePinSettings: Bool {
        guard profile != nil, isCurrentProfileAdmin else { return false }
        guard !isUpdatingPin else { return false }

        if pinEnabled {
            return newPin.count == 4 && newPin == confirmNewPin
        } else {
            return originalPinEnabled
        }
    }

    private var pinActionButtonTitle: String {
        if pinEnabled {
            if originalPinEnabled {
                return showPinEditor ? "profiles.save.new.pin".localized : "profiles.update.pin".localized
            } else {
                return showPinEditor ? "profiles.save.pin".localized : "profiles.enable.pin".localized
            }
        } else {
            return "profiles.remove.pin".localized
        }
    }

    // MARK: - Profile Management Info
    private var profileManagementInfoSection: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(AppColors.infoBlue)
                Text("profiles.before.you.delete".localized)
                    .headlineMedium()
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ProfileInfoRow(
                    icon: "photo.stack.fill",
                    title: "profiles.artwork.stays.safe".localized,
                    description: "profiles.artwork.stays.safe.desc".localized
                )

                ProfileInfoRow(
                    icon: "eye.fill",
                    title: "profiles.parent.visibility".localized,
                    description: "profiles.parent.visibility.desc".localized
                )

                ProfileInfoRow(
                    icon: "person.badge.plus.fill",
                    title: "profiles.free.up.slots".localized,
                    description: "profiles.free.up.slots.desc".localized
                )

                ProfileInfoRow(
                    icon: "lock.shield.fill",
                    title: "profiles.admin.control".localized,
                    description: "profiles.admin.control.desc".localized
                )
            }
        }
        .cardStyle()
    }

    // MARK: - Delete Section
    private var deleteProfileSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("profiles.delete.profile".localized)
                .headlineMedium()
                .foregroundColor(AppColors.errorRed)

            Text("profiles.delete.permanent".localized)
                .captionLarge()
                .foregroundColor(AppColors.textSecondary)

            Button {
                showingDeleteAlert = true
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "trash.fill")
                    Text("profiles.delete.this.profile".localized)
                }
                .largeButtonStyle(
                    backgroundColor: AppColors.errorRed,
                    isDisabled: isDeleting
                )
            }
            .disabled(isDeleting)
        }
        .cardStyle()
    }

    // MARK: - Cannot Delete Section
    private var cannotDeleteSection: some View {
        VStack(spacing: AppSpacing.md) {
            Text("profiles.profile.protection".localized)
                .headlineMedium()
                .foregroundColor(AppColors.textPrimary)

            Button {
                showingCannotDeleteAlert = true
            } label: {
                HStack {
                    Image(systemName: "lock.shield.fill")
                    Text("profiles.cannot.delete".localized)
                }
            }
            .largeButtonStyle(
                backgroundColor: AppColors.buttonDisabled,
                foregroundColor: AppColors.textSecondary,
                isDisabled: true
            )
            .disabled(true)

            VStack(spacing: AppSpacing.xs) {
                Text("profiles.main.cannot.delete.desc".localized)
                    .captionMedium()
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)

                Text("profiles.required.for.account".localized)
                    .captionMedium()
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .cardStyle()
    }

    // MARK: - Permission Management Methods
    private func loadCurrentPermissions() {
        guard let profile = profile else { return }

        #if DEBUG
        print("🔄 EditProfileView: loadCurrentPermissions() called")
        print("   - Profile: \(profile.name) (ID: \(profile.id))")
        print("   - OLD canMakePurchases state: \(canMakePurchases)")
        print("   - OLD canUseCustomContentTypes state: \(canUseCustomContentTypes)")
        print("   - Profile.canMakePurchases: \(profile.canMakePurchases)")
        print("   - Profile.canUseCustomContentTypes: \(profile.canUseCustomContentTypes)")
        #endif

        canMakePurchases = profile.canMakePurchases
        canUseCustomContentTypes = profile.canUseCustomContentTypes

        #if DEBUG
        print("   - NEW canMakePurchases state: \(canMakePurchases)")
        print("   - NEW canUseCustomContentTypes state: \(canUseCustomContentTypes)")
        print("   - Profile.isDefault: \(profile.isDefault)")
        print("   - isCurrentProfileAdmin: \(isCurrentProfileAdmin)")
        #endif
    }

    private func updatePermissions() {
        guard let profile = profile else { return }

        #if DEBUG
        print("   - Profile ID: \(profile.id)")
        print("   - Profile Name: \(profile.name)")
        print("   - isCurrentProfileAdmin: \(isCurrentProfileAdmin)")
        print("   - canMakePurchases: \(canMakePurchases)")
        print("   - canUseCustomContentTypes: \(canUseCustomContentTypes)")
        #endif

        guard isCurrentProfileAdmin else {
            #if DEBUG
            print("Permission update blocked - admin access required")
            #endif
            return
        }

        isUpdatingPermissions = true

        Task {
            do {
                let request = UpdateProfileRequest(
                    name: nil, // Not updating name
                    avatar: nil, // Not updating avatar
                    pin: nil, // Not updating PIN
                    canMakePurchases: canMakePurchases,
                    canUseCustomContentTypes: canUseCustomContentTypes
                )

                #if DEBUG
                print("📤 EditProfileView: Sending updateFamilyProfile request")
                print("   - Profile ID: \(profile.id)")
                print("   - canMakePurchases (sending): \(canMakePurchases)")
                print("   - canUseCustomContentTypes (sending): \(canUseCustomContentTypes)")
                print("   - Request object: \(request)")
                #endif

                let updatedProfile = try await ProfileService.shared.updateFamilyProfile(
                    profileId: profile.id,
                    request: request
                )

                #if DEBUG
                // Profile updated successfully
                print("   - Updated Profile: canMakePurchases=\(updatedProfile.canMakePurchases), canUseCustomContentTypes=\(updatedProfile.canUseCustomContentTypes)")
                #endif

                await MainActor.run {
                    onProfileUpdated(updatedProfile)

                    // Update local state with the returned values
                    canMakePurchases = updatedProfile.canMakePurchases
                    canUseCustomContentTypes = updatedProfile.canUseCustomContentTypes

                    isUpdatingPermissions = false
                }
            } catch {
                #if DEBUG
                print("Failed to update profile: \(error)")
                #endif

                await MainActor.run {
                    // Revert the UI state if API call failed
                    if let currentProfile = self.profile {
                        canMakePurchases = currentProfile.canMakePurchases
                        canUseCustomContentTypes = currentProfile.canUseCustomContentTypes
                    }

                    isUpdatingPermissions = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }

    private func updatePinSettings() {
        guard let profile = profile else { return }

        guard isCurrentProfileAdmin else {
            #if DEBUG
            print("❌ PIN update blocked - admin access required")
            #endif
            return
        }

        if pinEnabled && !(newPin.count == 4 && newPin == confirmNewPin) {
            return
        }

        isUpdatingPin = true

        let desiredPinState = pinEnabled
        let hadPinBefore = originalPinEnabled
        let pinValueToSend: String? = desiredPinState ? newPin : nil

        Task {
            do {
                let updatedProfile = try await ProfileService.shared.updateProfilePIN(
                    profileId: profile.id,
                    newPIN: pinValueToSend
                )

                await MainActor.run {
                    self.profile = updatedProfile
                    self.onProfileUpdated(updatedProfile)

                    self.pinEnabled = updatedProfile.hasPin
                    self.originalPinEnabled = updatedProfile.hasPin
                    self.newPin = ""
                    self.confirmNewPin = ""
                    self.showPinEditor = false
                    self.isUpdatingPin = false

                    if updatedProfile.hasPin && hadPinBefore {
                        pinAlertTitle = "profiles.pin.updated.title".localized
                        pinAlertMessage = String(format: "profiles.pin.updated.message".localized, updatedProfile.name)
                    } else if updatedProfile.hasPin {
                        pinAlertTitle = "profiles.pin.enabled.title".localized
                        pinAlertMessage = String(format: "profiles.pin.enabled.message".localized, updatedProfile.name)
                    } else {
                        pinAlertTitle = "profiles.pin.removed.title".localized
                        pinAlertMessage = String(format: "profiles.pin.removed.message".localized, updatedProfile.name)
                    }

                    showingPinAlert = true
                }
            } catch {
                await MainActor.run {
                    self.isUpdatingPin = false
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }

    // MARK: - Methods
    private func deleteProfile() {
        guard let profile = profile else { return }
        guard !profile.isDefault else {
            showingCannotDeleteAlert = true
            return
        }

        isDeleting = true

        Task {
            do {
                try await ProfileService.shared.deleteFamilyProfile(profileId: profile.id)

                await MainActor.run {
                    onProfileDeleted(profile)
                    isDeleting = false
                    successMessage = String(format: "profiles.deleted.message".localized, profile.name)
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Profile Selection View

struct ProfileSelectionView: View {
    let profile: FamilyProfile
    let onProfileSelected: (FamilyProfile) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.xl) {
                // Header
                VStack(spacing: AppSpacing.lg) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: profile.profileColor))
                            .frame(width: 120, height: 120)
                            .shadow(
                                color: Color(hex: profile.profileColor).opacity(0.3),
                                radius: AppSizing.shadows.large.radius,
                                x: AppSizing.shadows.large.x,
                                y: AppSizing.shadows.large.y
                            )

                        Text(profile.displayAvatar)
                            .font(.system(size: 60))
                    }

                    VStack(spacing: AppSpacing.sm) {
                        Text(String(format: "profiles.switch.profile.question".localized, profile.name))
                            .headlineLarge()
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)

                        if profile.hasPin {
                            Text("profiles.protected.with.pin".localized)
                                .bodyMedium()
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("profiles.ready.to.create".localized)
                                .bodyMedium()
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .contentPadding()

                Spacer()

                // Action Buttons
                VStack(spacing: AppSpacing.md) {
                    Button {
                        if profile.hasPin {
                            dismiss()
                            // This will trigger the PIN entry view
                            onProfileSelected(profile)
                        } else {
                            onProfileSelected(profile)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            if profile.hasPin {
                                Image(systemName: "lock.fill")
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text(profile.hasPin ? "profiles.enter.pin".localized : "profiles.tap.to.switch".localized)
                        }
                        .font(AppTypography.titleMedium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppColors.primaryBlue)
                        .cornerRadius(AppSizing.cornerRadius.lg)
                    }
                    .childSafeTouchTarget()

                    Button("profiles.cancel.button".localized) {
                        dismiss()
                    }
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .childSafeTouchTarget()
                }
                .contentPadding()
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("profiles.tap.to.switch".localized)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
    }
}

// MARK: - PIN Entry View

struct PINEntryView: View {
    let profile: FamilyProfile
    let onPINVerified: (FamilyProfile, String) -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var enteredPIN = ""
    @State private var isVerifying = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var attempts = 0
    @State private var showingForgotPINConfirmation = false
    @State private var isSendingPINRecovery = false
    @State private var showingForgotPINSuccess = false

    private let maxAttempts = 3

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
                // Header
                VStack(spacing: AppSpacing.lg) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: profile.profileColor))
                            .frame(width: 100, height: 100)
                            .shadow(
                                color: Color(hex: profile.profileColor).opacity(0.3),
                                radius: AppSizing.shadows.medium.radius,
                                x: AppSizing.shadows.medium.x,
                                y: AppSizing.shadows.medium.y
                            )

                        Text(profile.displayAvatar)
                            .font(.system(size: 50))

                        // Lock overlay
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "lock.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .background(
                                        Circle()
                                            .fill(.black.opacity(0.4))
                                            .frame(width: 32, height: 32)
                                    )
                            }
                        }
                        .frame(width: 100, height: 100)
                    }

                    VStack(spacing: AppSpacing.sm) {
                        Text(String(format: "profiles.enter.pin.title".localized, profile.name))
                            .headlineLarge()
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)

                        Text("profiles.enter.pin.to.access".localized)
                            .bodyMedium()
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .contentPadding()

                // PIN Input
                VStack(spacing: AppSpacing.lg) {
                    HStack(spacing: AppSpacing.md) {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(index < enteredPIN.count ? AppColors.primaryBlue : AppColors.borderLight)
                                .frame(width: 20, height: 20)
                        }
                    }

                    SecureField("", text: $enteredPIN)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(AppTypography.headlineLarge)
                        .multilineTextAlignment(.center)
                        .keyboardType(.numberPad)
                        .padding(AppSpacing.lg)
                        .background(AppColors.backgroundLight)
                        .cornerRadius(AppSizing.cornerRadius.lg)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                                .stroke(
                                    enteredPIN.count == 4 ? AppColors.primaryBlue : AppColors.borderMedium,
                                    lineWidth: 2
                                )
                        )
                        .onChange(of: enteredPIN) { oldValue, newValue in
                            // Limit to 4 digits
                            if newValue.count > 4 {
                                enteredPIN = String(newValue.prefix(4))
                            }

                            // Auto-verify when 4 digits entered
                            if enteredPIN.count == 4 {
                                verifyPIN()
                            }
                        }

                    if attempts > 0 {
                        Text(String(format: "profiles.incorrect.pin.attempts".localized, maxAttempts - attempts))
                            .captionLarge()
                            .foregroundColor(AppColors.errorRed)
                            .multilineTextAlignment(.center)
                    }
                }
                .contentPadding()

                Spacer()

                // Action Buttons
                VStack(spacing: AppSpacing.md) {
        Button(action: {
            verifyPIN()
        }) {
            HStack {
                Image(systemName: "lock.open.fill")
                Text("profiles.unlock.button".localized)
            }
            .largeButtonStyle(
                backgroundColor: AppColors.primaryBlue,
                isDisabled: enteredPIN.count != 4
            )
        }
        .disabled(enteredPIN.count != 4)
                    .childSafeTouchTarget()

                    // Forgot PIN Button
                    Button {
                        showingForgotPINConfirmation = true
                    } label: {
                        Text("profiles.forgot.pin".localized)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.primaryBlue)
                    }
                    .childSafeTouchTarget()

                    Button("profiles.cancel.button".localized) {
                        onCancel()
                        dismiss()
                    }
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .childSafeTouchTarget()
                }
                .contentPadding()
        }
        .background(AppColors.backgroundLight)
        .alert("profiles.pin.error.title".localized, isPresented: $showingError) {
            Button("common.ok".localized) {
                enteredPIN = ""
            }
        } message: {
            Text(errorMessage)
        }
        .alert("profiles.reset.pin.title".localized, isPresented: $showingForgotPINConfirmation) {
            Button("common.cancel".localized, role: .cancel) { }
            Button("profiles.send.email.button".localized) {
                requestPINRecovery()
            }
        } message: {
            Text("profiles.forgot.pin.message".localized)
        }
        .alert("profiles.pin.sent.title".localized, isPresented: $showingForgotPINSuccess) {
            Button("common.ok".localized) { }
        } message: {
            Text("profiles.check.email.for.pin".localized)
        }
    }

    private func verifyPIN() {
        guard enteredPIN.count == 4 else { return }

        isVerifying = true

        Task {
            do {
                // Use selectProfile instead of verifyProfilePIN
                try await ProfileService.shared.selectProfile(profile, pin: enteredPIN)

                await MainActor.run {
                    // Profile selection successful
                    onPINVerified(profile, enteredPIN)
                    dismiss()
                    isVerifying = false
                }
            } catch {
                await MainActor.run {
                    attempts += 1

                    if attempts >= maxAttempts {
                        errorMessage = "profiles.too.many.attempts".localized
                        showingError = true

                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            onCancel()
                            dismiss()
                        }
                    } else {
                        // Show backend error message
                        errorMessage = error.localizedDescription
                        showingError = true
                        enteredPIN = ""
                    }

                    isVerifying = false
                }
            }
        }
    }

    private func requestPINRecovery() {
        isSendingPINRecovery = true

        Task {
            do {
                try await ProfileService.shared.forgotProfilePIN(profileId: profile.id)

                await MainActor.run {
                    isSendingPINRecovery = false
                    showingForgotPINSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSendingPINRecovery = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

#if DEBUG
struct ProfilesView_Previews: PreviewProvider {
    static var previews: some View {
        ProfilesView()
    }
}
#endif
