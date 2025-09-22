import SwiftUI

struct SettingsView: View {
    @StateObject private var authService = AuthService.shared
    @State private var showingSignOutAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    
                    // Header
                    VStack(spacing: AppSpacing.lg) {
                        ZStack {
                            Circle()
                                .fill(AppColors.primaryBlue)
                                .frame(width: 120, height: 120)
                                .shadow(
                                    color: AppColors.primaryBlue.opacity(0.3),
                                    radius: AppSizing.shadows.large.radius,
                                    x: AppSizing.shadows.large.x,
                                    y: AppSizing.shadows.large.y
                                )
                            
                            Text("⚙️")
                                .font(.system(size: 60))
                        }
                        
                        VStack(spacing: AppSpacing.sm) {
                            Text("Settings")
                                .displayMedium()
                                .foregroundColor(AppColors.textPrimary)
                                .multilineTextAlignment(.center)
                            
                            if let user = authService.currentUser {
                                Text("Hello, \(user.name)!")
                                    .bodyMedium()
                                    .foregroundColor(AppColors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .contentPadding()
                    
                    // Account Section
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Account")
                            .headlineMedium()
                            .foregroundColor(AppColors.textPrimary)
                        
                        if let user = authService.currentUser {
                            VStack(spacing: AppSpacing.sm) {
                                SettingsRow(
                                    icon: "✉️",
                                    title: "Email",
                                    value: user.email,
                                    showChevron: false
                                )
                                
                                SettingsRow(
                                    icon: user.emailVerified ? "✅" : "⚠️",
                                    title: "Email Verification",
                                    value: user.emailVerified ? "Verified" : "Not Verified",
                                    showChevron: false
                                )
                            }
                        }
                    }
                    .cardStyle()
                    
                    // App Settings Section
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("App Settings")
                            .headlineMedium()
                            .foregroundColor(AppColors.textPrimary)
                        
                        VStack(spacing: AppSpacing.sm) {
                            SettingsRow(
                                icon: "🔔",
                                title: "Notifications",
                                value: "Coming Soon",
                                showChevron: true
                            )
                            
                            SettingsRow(
                                icon: "🌐",
                                title: "Language",
                                value: "English",
                                showChevron: true
                            )
                            
                            SettingsRow(
                                icon: "🎨",
                                title: "Theme",
                                value: "Light",
                                showChevron: true
                            )
                        }
                    }
                    .cardStyle()
                    
                    // Support Section
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Support")
                            .headlineMedium()
                            .foregroundColor(AppColors.textPrimary)
                        
                        VStack(spacing: AppSpacing.sm) {
                            SettingsRow(
                                icon: "❓",
                                title: "Help & FAQ",
                                value: "",
                                showChevron: true
                            )
                            
                            SettingsRow(
                                icon: "📝",
                                title: "Privacy Policy",
                                value: "",
                                showChevron: true
                            )
                            
                            SettingsRow(
                                icon: "📋",
                                title: "Terms of Service",
                                value: "",
                                showChevron: true
                            )
                        }
                    }
                    .cardStyle()
                    
                    // Sign Out Section
                    VStack(spacing: AppSpacing.sm) {
                        Button("Sign Out") {
                            showingSignOutAlert = true
                        }
                        .buttonStyle(
                            backgroundColor: AppColors.buttonSecondary,
                            foregroundColor: AppColors.errorRed
                        )
                        
                        Text("You can always sign back in anytime")
                            .captionLarge()
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .contentPadding()
                }
                .pageMargins()
                .padding(.vertical, AppSpacing.sectionSpacing)
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                authService.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String
    let showChevron: Bool
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Text(icon)
                .font(.system(size: AppSizing.iconSizes.md))
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .bodyMedium()
                    .foregroundColor(AppColors.textPrimary)
                
                if !value.isEmpty {
                    Text(value)
                        .captionLarge()
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: AppSizing.iconSizes.sm, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .contentPadding()
        .background(AppColors.backgroundLight)
        .cornerRadius(AppSizing.cornerRadius.sm)
        .childSafeTouchTarget()
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .onAppear {
                // Set mock user for preview
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
                AuthService.shared.isAuthenticated = true
            }
    }
}
#endif