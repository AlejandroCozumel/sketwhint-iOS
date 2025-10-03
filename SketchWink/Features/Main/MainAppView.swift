import SwiftUI

struct MainAppView: View {
    @State private var selectedTab = 0
    @StateObject private var tokenManager = TokenBalanceManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Network status banner (only shows when there are issues)
            NetworkStatusBanner()
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)

            TabView(selection: $selectedTab) {
            // Art tab with CategorySelectionView
            NavigationStack {
                CategorySelectionView(selectedTab: $selectedTab)
            }
            .tabItem {
                Label("Art", systemImage: "paintbrush.fill")
            }
            .tag(0)

            NavigationStack {
                GalleryView(selectedTab: $selectedTab)
            }
            .tabItem {
                Label("Gallery", systemImage: "photo.fill")
            }
            .tag(1)

            NavigationStack {
                BooksView()
            }
            .tabItem {
                Label("Books", systemImage: "book.fill")
            }
            .tag(2)

            NavigationStack {
                FolderView(selectedTab: $selectedTab)
            }
            .tabItem {
                Label("Folders", systemImage: "folder.fill")
            }
            .tag(3)

            NavigationStack {
                ProfilesView()
            }
            .tabItem {
                Label("Profiles", systemImage: "person.2.fill")
            }
            .tag(4)
            }
            .tint(AppColors.primaryBlue)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Silent token refresh when navigating to Art tab (tab 0)
            if newValue == 0 {
                Task {
                    await tokenManager.refreshSilently()
                }
            }
        }
        .onAppear {
            // Configure tab bar appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(AppColors.backgroundLight)

            // Configure normal state
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppColors.textSecondary)
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor(AppColors.textSecondary),
                .font: UIFont.systemFont(ofSize: 12, weight: .medium)
            ]

            // Configure selected state
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppColors.primaryBlue)
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor(AppColors.primaryBlue),
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
            ]

            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance

            // Configure navigation bar large title to use our rounded typography
            let navBarAppearance = UINavigationBarAppearance()
            navBarAppearance.configureWithDefaultBackground()

            // 34pt bold rounded - same style as our app typography
            if let descriptor = UIFont.systemFont(ofSize: 34, weight: .bold).fontDescriptor.withDesign(.rounded) {
                navBarAppearance.largeTitleTextAttributes = [
                    .font: UIFont(descriptor: descriptor, size: 34)
                ]
            }

            UINavigationBar.appearance().standardAppearance = navBarAppearance
            UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
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

struct FeatureCardContent: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
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