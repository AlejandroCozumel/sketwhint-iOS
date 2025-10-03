import SwiftUI

/// Quick profile switcher for easy profile changing within the app
/// Shows current profile and allows switching without going through full profile selection flow
struct ProfileSwitcherView: View {
    @ObservedObject private var profileService = ProfileService.shared
    @State private var showingProfileSelection = false
    @State private var showingPINEntry = false
    @State private var profileToSelect: FamilyProfile?
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showingError = false
    
    var body: some View {
        Button {
            #if DEBUG
            print("🟡 ProfileSwitcher: Button tapped!")
            #endif
            showProfileSwitcher()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                // Current profile avatar
                if let currentProfile = profileService.currentProfile {
                    profileAvatarView(currentProfile)
                    
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(currentProfile.name)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                        
                        if currentProfile.isDefault {
                            Text("Main Profile")
                                .font(AppTypography.captionMedium)
                                .foregroundColor(AppColors.primaryBlue)
                        } else {
                            Text("Family Member")
                                .font(AppTypography.captionMedium)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.system(size: AppSizing.iconSizes.sm))
                        .foregroundColor(AppColors.primaryBlue)
                } else {
                    // No profile selected state
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text("Select Profile")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Spacer()
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: AppSizing.iconSizes.sm))
                        .foregroundColor(AppColors.warningOrange)
                }
            }
            .contentPadding()
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                .fill(AppColors.surfaceLight)
                .stroke(AppColors.borderLight, lineWidth: 1)
        )
        .childSafeTouchTarget()
        .sheet(isPresented: $showingProfileSelection) {
            // Always show the profile list for selection
            ProfileSwitcherListView(
                availableProfiles: profileService.availableProfiles,
                currentProfile: profileService.currentProfile,
                onProfileSelected: { selectedProfile in
                    profileToSelect = selectedProfile
                    
                    if selectedProfile.hasPin {
                        showingProfileSelection = false
                        showingPINEntry = true
                    } else {
                        Task {
                            await switchToProfile(selectedProfile, pin: nil)
                        }
                    }
                }
            )
            .onAppear {
                #if DEBUG
                print("📋 ProfileSwitcherListView appeared with \(profileService.availableProfiles.count) profiles")
                #endif
                
                // Safety check: if profiles are empty when sheet appears, reload them
                if profileService.availableProfiles.isEmpty {
                    #if DEBUG
                    print("⚠️ ProfileSwitcherListView: Profiles are empty, reloading...")
                    #endif
                    
                    // Close the sheet and reload profiles
                    showingProfileSelection = false
                    loadProfilesAndShowSwitcher()
                }
            }
        }
        .sheet(isPresented: $showingPINEntry) {
            if let profile = profileToSelect {
                PINEntryView(
                    profile: profile,
                    onPINVerified: { verifiedProfile, pin in
                        Task {
                            await switchToProfile(verifiedProfile, pin: pin)
                        }
                    },
                    onCancel: {
                        showingPINEntry = false
                        profileToSelect = nil
                    }
                )
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(error?.localizedDescription ?? "An error occurred while switching profiles")
        }
    }
    
    // MARK: - Profile Avatar View
    private func profileAvatarView(_ profile: FamilyProfile) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: profile.profileColor))
                .frame(width: 40, height: 40)
            
            Text(profile.displayAvatar)
                .font(.system(size: 20))
            
            // Badge for main profile
            if profile.isDefault {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(AppColors.warningOrange)
                                    .frame(width: 16, height: 16)
                            )
                    }
                    Spacer()
                }
                .frame(width: 40, height: 40)
            }
        }
    }
    
    // MARK: - Methods
    private func showProfileSwitcher() {
        guard !isLoading else { return }
        
        #if DEBUG
        print("🔍 ProfileSwitcher: showProfileSwitcher called")
        print("   - Available profiles count: \(profileService.availableProfiles.count)")
        print("   - Current profile: \(profileService.currentProfile?.name ?? "nil")")
        #endif
        
        // Always ensure we have fresh profiles data
        // This handles cases where app restarted and profiles might be stale
        if profileService.availableProfiles.isEmpty {
            #if DEBUG
            print("   - Loading profiles because array is empty")
            #endif
            loadProfilesAndShowSwitcher()
        } else {
            #if DEBUG
            print("   - Using existing profiles, showing switcher")
            #endif
            showingProfileSelection = true
        }
    }
    
    private func loadProfilesAndShowSwitcher() {
        isLoading = true
        
        #if DEBUG
        print("📡 ProfileSwitcher: Loading profiles from API...")
        #endif
        
        Task {
            do {
                let profiles = try await profileService.loadFamilyProfiles()
                
                #if DEBUG
                print("📡 ProfileSwitcher: Loaded \(profiles.count) profiles from API")
                print("   - Profiles: \(profiles.map { "\($0.name) (\($0.id))" }.joined(separator: ", "))")
                #endif
                
                await MainActor.run {
                    isLoading = false
                    if !profiles.isEmpty {
                        #if DEBUG
                        print("📡 ProfileSwitcher: Showing profile selection with \(profiles.count) profiles")
                        #endif
                        showingProfileSelection = true
                    } else {
                        // No profiles available - should not happen in normal flow
                        #if DEBUG
                        print("❌ ProfileSwitcher: No profiles loaded, showing error")
                        #endif
                        error = ProfileError.apiError("No profiles available")
                        showingError = true
                    }
                }
            } catch {
                #if DEBUG
                print("❌ ProfileSwitcher: Failed to load profiles: \(error)")
                #endif
                await MainActor.run {
                    isLoading = false
                    self.error = error
                    showingError = true
                }
            }
        }
    }
    
    private func switchToProfile(_ profile: FamilyProfile, pin: String?) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            try await profileService.selectProfile(profile, pin: pin)
            
            await MainActor.run {
                isLoading = false
                showingProfileSelection = false
                showingPINEntry = false
                profileToSelect = nil
                
                #if DEBUG
                print("✅ ProfileSwitcher: Successfully switched to profile: \(profile.name)")
                #endif
            }
        } catch {
            await MainActor.run {
                isLoading = false
                self.error = error
                showingError = true
                
                #if DEBUG
                print("❌ ProfileSwitcher: Failed to switch profile: \(error)")
                #endif
            }
        }
    }
}

// MARK: - Profile Switcher List View
struct ProfileSwitcherListView: View {
    let availableProfiles: [FamilyProfile]
    let currentProfile: FamilyProfile?
    let onProfileSelected: (FamilyProfile) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    // Header
                    headerSection
                    
                    // Handle empty profiles case
                    if availableProfiles.isEmpty {
                        emptyProfilesSection
                    } else {
                        // All Profiles (with current profile highlighted)
                        availableProfilesSection
                    }
                }
                .pageMargins()
                .padding(.vertical, AppSpacing.sectionSpacing)
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("Switch Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.primaryBlue)
                }
            }
        }
    }
    
    // MARK: - Empty Profiles Section
    private var emptyProfilesSection: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppColors.primaryBlue)
            
            Text("Loading profiles...")
                .bodyMedium()
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xl)
        .cardStyle()
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppColors.primaryBlue)

            VStack(spacing: AppSpacing.sm) {
                Text("Choose Profile")
                    .headlineLarge()
                    .foregroundColor(AppColors.textPrimary)

                Text("Select which family member you want to be")
                    .bodyMedium()
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .contentPadding()
    }
    
    // MARK: - All Profiles Section
    private var availableProfilesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Family Profiles")
                .headlineMedium()
                .foregroundColor(AppColors.textPrimary)
            
            VStack(spacing: AppSpacing.sm) {
                ForEach(availableProfiles) { profile in
                    ProfileRowView(
                        profile: profile,
                        isSelected: profile.id == currentProfile?.id,
                        onTap: {
                            if profile.id == currentProfile?.id {
                                // Already selected profile - just dismiss
                                dismiss()
                            } else {
                                // Different profile - proceed with selection
                                onProfileSelected(profile)
                                dismiss()
                            }
                        }
                    )
                }
            }
            
            if availableProfiles.count == 1 {
                Text("Create additional profiles in Profile Settings")
                    .bodyMedium()
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(AppSpacing.lg)
            }
        }
        .cardStyle()
    }
}

// MARK: - Profile Row View
struct ProfileRowView: View {
    let profile: FamilyProfile
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: AppSpacing.md) {
                // Profile avatar
                ZStack {
                    Circle()
                        .fill(Color(hex: profile.profileColor))
                        .frame(width: 48, height: 48)
                    
                    Text(profile.displayAvatar)
                        .font(.system(size: 24))
                    
                    // Main profile crown
                    if profile.isDefault {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                                    .background(
                                        Circle()
                                            .fill(AppColors.warningOrange)
                                            .frame(width: 20, height: 20)
                                    )
                            }
                            Spacer()
                        }
                        .frame(width: 48, height: 48)
                    }
                    
                    // PIN indicator
                    if profile.hasPin {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "lock.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .background(
                                        Circle()
                                            .fill(.black.opacity(0.3))
                                            .frame(width: 20, height: 20)
                                    )
                            }
                        }
                        .frame(width: 48, height: 48)
                    }
                }
                
                // Profile info
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        Text(profile.name)
                            .font(AppTypography.bodyLarge)
                            .foregroundColor(AppColors.textPrimary)
                        
                        if profile.isDefault {
                            Text("MAIN")
                                .captionMedium()
                                .foregroundColor(.white)
                                .padding(.horizontal, AppSpacing.xs)
                                .padding(.vertical, 2)
                                .background(AppColors.warningOrange)
                                .cornerRadius(AppSizing.cornerRadius.xs)
                        }
                        
                        Spacer()
                        
                        if isSelected {
                            VStack(spacing: AppSpacing.xs) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(AppColors.successGreen)
                                
                                Text("Active")
                                    .captionMedium()
                                    .foregroundColor(AppColors.successGreen)
                            }
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    
                    HStack(spacing: AppSpacing.sm) {
                        if profile.canMakePurchases {
                            Label("Can purchase", systemImage: "creditcard.fill")
                                .font(AppTypography.captionMedium)
                                .foregroundColor(AppColors.warningOrange)
                        }
                        
                        if profile.hasPin {
                            Label("PIN protected", systemImage: "lock.fill")
                                .font(AppTypography.captionMedium)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
            .contentPadding()
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                .fill(isSelected ? AppColors.primaryBlue.opacity(0.1) : AppColors.surfaceLight)
                .stroke(
                    isSelected ? AppColors.primaryBlue : AppColors.borderLight,
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .childSafeTouchTarget()
    }
}