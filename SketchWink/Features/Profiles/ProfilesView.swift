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
    @State private var profileToSelect: FamilyProfile?
    @State private var showingPINEntry = false
    
    var body: some View {
        NavigationStack {
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
                .padding(.vertical, AppSpacing.sectionSpacing)
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("Family Profiles")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !profiles.isEmpty {
                        Button {
                            if canCreateProfile {
                                showingCreateProfile = true
                            } else {
                                handleProfileCreationLimit()
                            }
                        } label: {
                            Image(systemName: canCreateProfile ? "plus.circle.fill" : (isFreePlan ? "lock.circle.fill" : "exclamationmark.circle.fill"))
                                .font(.system(size: 24))
                                .foregroundColor(canCreateProfile ? AppColors.primaryBlue : AppColors.warningOrange)
                        }
                        .childSafeTouchTarget()
                    }
                }
            }
        }
        .task {
            await loadData()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(error?.localizedDescription ?? "An error occurred")
        }
        .alert("Maximum Profiles Reached", isPresented: $showingMaxProfilesAlert) {
            Button("OK") { }
        } message: {
            Text("You've reached the maximum of \(userPermissions?.maxFamilyProfiles ?? 5) family profiles for your plan.")
        }
        .sheet(isPresented: $showingCreateProfile) {
            CreateProfileView(
                maxProfiles: userPermissions?.maxFamilyProfiles ?? 1,
                onProfileCreated: { newProfile in
                    profiles.append(newProfile)
                    // After creating profile, force user to select it
                    profileToSelect = newProfile
                    showingProfileSelection = true
                }
            )
        }
        .sheet(item: $selectedProfile) { profile in
            EditProfileView(
                profile: profile,
                onProfileUpdated: { updatedProfile in
                    if let index = profiles.firstIndex(where: { $0.id == updatedProfile.id }) {
                        profiles[index] = updatedProfile
                    }
                },
                onProfileDeleted: { deletedProfile in
                    profiles.removeAll { $0.id == deletedProfile.id }
                }
            )
        }
        .sheet(isPresented: $showingSubscriptionPlans) {
            SubscriptionPlansView(
                highlightedFeature: highlightedFeature,
                currentPlan: userPermissions?.planName.lowercased()
            )
        }
        .sheet(isPresented: $showingProfileSelection) {
            if let profile = profileToSelect {
                ProfileSelectionView(
                    profile: profile,
                    onProfileSelected: { selectedProfile in
                        if selectedProfile.hasPin {
                            // Switch to PIN entry
                            showingProfileSelection = false
                            showingPINEntry = true
                        } else {
                            Task {
                                await selectProfile(selectedProfile, pin: nil)
                            }
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingPINEntry) {
            if let profile = profileToSelect {
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
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: AppSpacing.xl) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppColors.primaryBlue)
            
            Text("Loading family profiles...")
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
                    Text("Create Family Profiles")
                        .displayMedium()
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("Set up personalized profiles for each family member with custom avatars and parental controls")
                        .bodyMedium()
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .contentPadding()
            
            // Benefits Card
            VStack(spacing: AppSpacing.md) {
                Text("Family Profile Benefits")
                    .headlineMedium()
                    .foregroundColor(AppColors.textPrimary)
                
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    ProfileBenefitItem(icon: "👶", title: "Child-Safe Profiles", description: "Age-appropriate content and controls")
                    ProfileBenefitItem(icon: "🔒", title: "PIN Protection", description: "Secure profiles with optional PIN access")
                    ProfileBenefitItem(icon: "🎨", title: "Personal Collections", description: "Individual art galleries and favorites")
                    ProfileBenefitItem(icon: "📊", title: "Usage Tracking", description: "Monitor creative progress and activity")
                }
            }
            .cardStyle()
            
            // Create First Profile Button
            Button("Create Your First Profile") {
                if canCreateProfile {
                    showingCreateProfile = true
                } else {
                    handleProfileCreationLimit()
                }
            }
            .largeButtonStyle(backgroundColor: AppColors.primaryPink)
            .childSafeTouchTarget()
        }
    }
    
    // MARK: - Profile Management View
    private var profileManagementView: some View {
        VStack(spacing: AppSpacing.sectionSpacing) {
            
            // Header with stats
            profilesHeaderView
            
            // Profiles Grid
            profilesGrid
            
            // Plan limits info
            planLimitsView
        }
    }
    
    // MARK: - Profiles Header
    private var profilesHeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Family Profiles")
                    .headlineLarge()
                    .foregroundColor(AppColors.textPrimary)
                
                Text("\(profiles.count) of \(userPermissions?.maxFamilyProfiles ?? 1) profiles created")
                    .captionLarge()
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
            
            Button {
                if canCreateProfile {
                    showingCreateProfile = true
                } else {
                    handleProfileCreationLimit()
                }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: canCreateProfile ? "plus.circle.fill" : (isFreePlan ? "lock.circle.fill" : "exclamationmark.circle.fill"))
                    Text(canCreateProfile ? "Add Profile" : (isFreePlan ? "Upgrade to Add" : "Limit Reached"))
                }
                .font(AppTypography.titleMedium)
                .foregroundColor(.white)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(canCreateProfile ? AppColors.primaryBlue : AppColors.warningOrange)
                .cornerRadius(AppSizing.cornerRadius.lg)
            }
            .childSafeTouchTarget()
        }
        .cardStyle()
    }
    
    // MARK: - Profiles Grid
    private var profilesGrid: some View {
        LazyVGrid(columns: GridLayouts.categoryGrid, spacing: AppSpacing.grid.rowSpacing) {
            ForEach(profiles) { profile in
                ProfileCard(
                    profile: profile,
                    onTap: {
                        selectedProfile = profile
                        showingEditProfile = true
                    }
                )
            }
        }
    }
    
    // MARK: - Plan Limits
    private var planLimitsView: some View {
        Group {
            if let permissions = userPermissions {
                VStack(spacing: AppSpacing.md) {
                    HStack {
                        Text("Plan Information")
                            .headlineMedium()
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                    }
                    
                    VStack(spacing: AppSpacing.sm) {
                        PlanInfoRow(
                            icon: "person.2.fill",
                            title: "Family Profiles",
                            value: "\(permissions.maxFamilyProfiles) profiles",
                            current: "\(profiles.count) used"
                        )
                        
                        if profiles.count >= permissions.maxFamilyProfiles {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(AppColors.warningOrange)
                                
                                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                    if isFreePlan {
                                        Text("Upgrade your plan to add more family profiles")
                                            .captionMedium()
                                            .foregroundColor(AppColors.textSecondary)
                                        
                                        Button("View Plans") {
                                            highlightedFeature = "Family Profiles"
                                            showingSubscriptionPlans = true
                                        }
                                        .font(AppTypography.captionLarge)
                                        .foregroundColor(AppColors.primaryBlue)
                                    } else {
                                        Text("You've reached the maximum of \(permissions.maxFamilyProfiles) family profiles")
                                            .captionMedium()
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                }
                                
                                Spacer()
                            }
                        }
                    }
                }
                .cardStyle()
            }
        }
    }
    
    // MARK: - Computed Properties
    private var canCreateProfile: Bool {
        guard let permissions = userPermissions else { return false }
        return profiles.count < permissions.maxFamilyProfiles
    }
    
    private var isFreePlan: Bool {
        guard let permissions = userPermissions else { return true }
        return permissions.maxFamilyProfiles <= 1
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
        if isFreePlan {
            // Free users: redirect to purchase modal
            highlightedFeature = "Family Profiles"
            showingSubscriptionPlans = true
        } else {
            // Paid users: show alert about maximum limit
            showingMaxProfilesAlert = true
        }
    }
    
    private func selectProfile(_ profile: FamilyProfile, pin: String?) async {
        do {
            // Use ProfileService's selectProfile method (calls API and stores locally)
            try await ProfileService.shared.selectProfile(profile, pin: pin)
            
            // Close modals and navigate to main app
            await MainActor.run {
                showingProfileSelection = false
                showingPINEntry = false
                profileToSelect = nil
                
                // TODO: Navigate to main app view or notify parent
                // This might require a callback to parent view or navigation coordinator
            }
        } catch {
            await MainActor.run {
                self.error = error
                showingError = true
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
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: AppSpacing.md) {
                // Avatar Circle
                ZStack {
                    Circle()
                        .fill(Color(hex: profile.profileColor))
                        .frame(width: 80, height: 80)
                    
                    Text(profile.displayAvatar)
                        .font(.system(size: 40))
                    
                    // PIN indicator
                    if profile.hasPin {
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
                }
                
                VStack(spacing: AppSpacing.xs) {
                    Text(profile.name)
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    if profile.isDefault {
                        Text("Admin")
                            .font(AppTypography.captionSmall)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(AppColors.backgroundLight)
            .cornerRadius(AppSizing.cornerRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                    .stroke(AppColors.borderLight, lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(0.05),
                radius: 4,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(PlainButtonStyle())
        .childSafeTouchTarget()
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
    let onProfileCreated: (FamilyProfile) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var profileName = ""
    @State private var selectedAvatar = "👤"
    @State private var enablePin = false
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var canMakePurchases = false
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
            .navigationTitle("Create Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primaryBlue)
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
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
                Text("Create Family Profile")
                    .headlineLarge()
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Set up a personalized profile with avatar and safety settings")
                    .bodyMedium()
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .contentPadding()
    }
    
    // MARK: - Avatar Selection
    private var avatarSelectionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Choose Avatar")
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
            Text("Profile Name")
                .headlineMedium()
                .foregroundColor(AppColors.textPrimary)
            
            TextField("Enter name (e.g., Emma, Dad, Mom)", text: $profileName)
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
                    Text("Name looks good!")
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
                Text("PIN Protection")
                    .headlineMedium()
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                Toggle("", isOn: $enablePin)
                    .labelsHidden()
                    .tint(AppColors.primaryBlue)
                    .childSafeTouchTarget()
            }
            
            Text("Add a 4-digit PIN to protect this profile from unauthorized access")
                .captionLarge()
                .foregroundColor(AppColors.textSecondary)
            
            if enablePin {
                VStack(spacing: AppSpacing.md) {
                    // PIN Input
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Enter 4-digit PIN")
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
                            Text("Confirm PIN")
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
                                
                                Text(confirmPin == pin ? "PINs match!" : "PINs don't match")
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
            Text("Permissions")
                .headlineMedium()
                .foregroundColor(AppColors.textPrimary)
            
            VStack(spacing: AppSpacing.md) {
                PermissionToggle(
                    icon: "creditcard.fill",
                    title: "Can Make Purchases",
                    description: "Allow this profile to make in-app purchases",
                    isOn: $canMakePurchases,
                    color: AppColors.warningOrange
                )
                
                PermissionToggle(
                    icon: "photo.fill",
                    title: "Can Use Custom Content",
                    description: "Allow uploading custom images for generation",
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
                    
                    Text(isCreating ? "Creating Profile..." : "Create Profile")
                }
                .font(AppTypography.titleMedium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(canCreateProfile ? AppColors.primaryBlue : AppColors.buttonDisabled)
                .cornerRadius(AppSizing.cornerRadius.lg)
            }
            .disabled(!canCreateProfile || isCreating)
            .childSafeTouchTarget()
            
            if !canCreateProfile {
                Text("Please fill in all required fields")
                    .captionMedium()
                    .foregroundColor(AppColors.errorRed)
                    .multilineTextAlignment(.center)
            }
        }
        .contentPadding()
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
                    onProfileCreated(newProfile)
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

struct EditProfileView: View {
    let profile: FamilyProfile
    let onProfileUpdated: (FamilyProfile) -> Void
    let onProfileDeleted: (FamilyProfile) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.xl) {
                Text("Edit Profile")
                    .headlineLarge()
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Coming soon: Profile editing with avatar change, PIN management, and permission settings")
                    .bodyMedium()
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Text("Profile: \(profile.name)")
                    .titleMedium()
                    .foregroundColor(AppColors.textPrimary)
                
                Button("Close") {
                    dismiss()
                }
                .largeButtonStyle(backgroundColor: AppColors.primaryBlue)
            }
            .pageMargins()
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
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
                        Text("Switch to \(profile.name)?")
                            .headlineLarge()
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        if profile.hasPin {
                            Text("This profile is protected with a PIN")
                                .bodyMedium()
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Ready to start creating!")
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
                            Text(profile.hasPin ? "Enter PIN" : "Switch Profile")
                        }
                        .font(AppTypography.titleMedium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(AppColors.primaryBlue)
                        .cornerRadius(AppSizing.cornerRadius.lg)
                    }
                    .childSafeTouchTarget()
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .childSafeTouchTarget()
                }
                .contentPadding()
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("Switch Profile")
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
                        Text("Enter PIN for \(profile.name)")
                            .headlineLarge()
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text("Enter your 4-digit PIN to access this profile")
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
                        Text("Incorrect PIN. \(maxAttempts - attempts) attempts remaining.")
                            .captionLarge()
                            .foregroundColor(AppColors.errorRed)
                            .multilineTextAlignment(.center)
                    }
                }
                .contentPadding()
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: AppSpacing.md) {
                    Button {
                        verifyPIN()
                    } label: {
                        HStack {
                            if isVerifying {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Image(systemName: "lock.open.fill")
                            }
                            Text(isVerifying ? "Verifying..." : "Unlock Profile")
                        }
                        .font(AppTypography.titleMedium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(enteredPIN.count == 4 && !isVerifying ? AppColors.primaryBlue : AppColors.buttonDisabled)
                        .cornerRadius(AppSizing.cornerRadius.lg)
                    }
                    .disabled(enteredPIN.count != 4 || isVerifying)
                    .childSafeTouchTarget()
                    
                    Button("Cancel") {
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
        .alert("PIN Error", isPresented: $showingError) {
            Button("OK") {
                enteredPIN = ""
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func verifyPIN() {
        guard enteredPIN.count == 4 else { return }
        
        isVerifying = true
        
        Task {
            do {
                let isValid = try await ProfileService.shared.verifyProfilePIN(
                    profileId: profile.id,
                    pin: enteredPIN
                )
                
                await MainActor.run {
                    if isValid {
                        // PIN correct
                        onPINVerified(profile, enteredPIN)
                        dismiss()
                    } else {
                        // This shouldn't happen since API throws on invalid PIN
                        errorMessage = "PIN verification failed"
                        showingError = true
                        enteredPIN = ""
                    }
                    isVerifying = false
                }
            } catch {
                await MainActor.run {
                    attempts += 1
                    
                    if attempts >= maxAttempts {
                        errorMessage = "Too many incorrect attempts. Please try again later."
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
}

#if DEBUG
struct ProfilesView_Previews: PreviewProvider {
    static var previews: some View {
        ProfilesView()
    }
}
#endif