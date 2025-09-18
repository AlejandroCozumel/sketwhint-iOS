import SwiftUI

struct MainAppView: View {
    @StateObject private var authService = AuthService.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    
                    // Welcome Header
                    VStack(spacing: AppSpacing.lg) {
                        // Success Animation Placeholder
                        ZStack {
                            Circle()
                                .fill(AppColors.primaryPurple)
                                .frame(width: 150, height: 150)
                                .shadow(
                                    color: AppColors.primaryPurple.opacity(0.3),
                                    radius: AppSizing.shadows.large.radius,
                                    x: AppSizing.shadows.large.x,
                                    y: AppSizing.shadows.large.y
                                )
                            
                            Text("🎉")
                                .font(.system(size: 80))
                        }
                        
                        VStack(spacing: AppSpacing.sm) {
                            Text("Welcome to SketchWink!")
                                .displayMedium()
                                .foregroundColor(AppColors.textPrimary)
                                .multilineTextAlignment(.center)
                            
                            if let user = authService.currentUser {
                                Text("Hello, \(user.name)! 👋")
                                    .onboardingTitle()
                                    .foregroundColor(AppColors.primaryBlue)
                            }
                            
                            Text("You're now logged in and ready to create amazing art with AI!")
                                .onboardingBody()
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .contentPadding()
                    
                    // Feature Preview Cards
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("What's Next?")
                            .headlineLarge()
                            .foregroundColor(AppColors.textPrimary)
                        
                        LazyVGrid(columns: GridLayouts.categoryGrid, spacing: AppSpacing.grid.rowSpacing) {
                            
                            FeatureCard(
                                title: "Create Art",
                                description: "Generate coloring pages, stickers, and more",
                                icon: "🎨",
                                color: AppColors.coloringPagesColor,
                                action: {
                                    // TODO: Navigate to generation
                                }
                            )
                            
                            FeatureCard(
                                title: "My Gallery",
                                description: "View and organize your creations",
                                icon: "🖼️",
                                color: AppColors.wallpapersColor,
                                action: {
                                    // TODO: Navigate to gallery
                                }
                            )
                            
                            FeatureCard(
                                title: "Family Profiles",
                                description: "Manage family member profiles",
                                icon: "👨‍👩‍👧‍👦",
                                color: AppColors.primaryPink,
                                action: {
                                    // TODO: Navigate to profiles
                                }
                            )
                            
                            FeatureCard(
                                title: "Settings",
                                description: "Customize your experience",
                                icon: "⚙️",
                                color: AppColors.primaryBlue,
                                action: {
                                    // TODO: Navigate to settings
                                }
                            )
                        }
                    }
                    .cardStyle()
                    
                    // User Info Card (Debug)
                    #if DEBUG
                    if let user = authService.currentUser {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("Debug: User Info")
                                .headlineMedium()
                                .foregroundColor(AppColors.textPrimary)
                            
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                InfoRow(label: "ID", value: user.id)
                                InfoRow(label: "Email", value: user.email)
                                InfoRow(label: "Name", value: user.name)
                                InfoRow(label: "Role", value: user.role ?? "user")
                                InfoRow(label: "Email Verified", value: user.emailVerified ? "Yes" : "No")
                                InfoRow(label: "Prompt Enhancement", value: (user.promptEnhancementEnabled ?? true) ? "Enabled" : "Disabled")
                            }
                        }
                        .cardStyle()
                    }
                    #endif
                    
                    // Sign Out Button
                    VStack(spacing: AppSpacing.sm) {
                        Button("Sign Out") {
                            authService.signOut()
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
            .navigationTitle("SketchWink")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Supporting Views
struct FeatureCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.sm) {
                Text(icon)
                    .font(.system(size: AppSizing.iconSizes.xl))
                
                VStack(spacing: AppSpacing.xs) {
                    Text(title)
                        .categoryTitle()
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(description)
                        .captionLarge()
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(height: 140)
            .frame(maxWidth: .infinity)
            .background(color)
            .cornerRadius(AppSizing.cornerRadius.md)
            .shadow(
                color: color.opacity(0.3),
                radius: AppSizing.shadows.small.radius,
                x: AppSizing.shadows.small.x,
                y: AppSizing.shadows.small.y
            )
        }
        .childSafeTouchTarget()
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .titleSmall()
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            Text(value)
                .bodyMedium()
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct MainAppView_Previews: PreviewProvider {
    static var previews: some View {
        MainAppView()
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