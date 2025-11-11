import SwiftUI

struct MainAppView: View {
    @State private var selectedTab: Tab = .art
    @StateObject private var tokenManager = TokenBalanceManager.shared
    @StateObject private var localization = LocalizationManager.shared

    init() {
        Self.configureAppearance()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.rawValue) { tab in
                ZStack(alignment: .top) {
                    // Tab content
                    tabContent(for: tab)

                    // Network status banner overlay (only visible when needed)
                    VStack {
                        NetworkStatusBanner()
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.top, AppSpacing.sm)
                        Spacer()
                    }
                    .allowsHitTesting(false) // Allow taps to pass through
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.systemImage)
                }
                .tag(tab)
            }
        }
        .tint(AppColors.primaryBlue)
        .onChange(of: selectedTab) { oldValue, newValue in
            // Silent token refresh when navigating to Art tab
            if newValue == .art {
                Task {
                    await tokenManager.refreshSilently()
                }
            }
        }
        .task {
            await tokenManager.initialize()
        }
    }
}

// MARK: - Tab Enumeration
extension MainAppView {
    enum Tab: Int, CaseIterable {
        case art = 0
        case gallery
        case stories
        case books
        case folders

        var title: String {
            switch self {
            case .art: return "nav.art".localized
            case .gallery: return "nav.gallery".localized
            case .stories: return "nav.stories".localized
            case .books: return "nav.books".localized
            case .folders: return "nav.folders".localized
            }
        }

        var systemImage: String {
            switch self {
            case .art: return "paintbrush.fill"
            case .gallery: return "photo.fill"
            case .stories: return "moon.stars.fill"
            case .books: return "book.fill"
            case .folders: return "folder.fill"
            }
        }
    }
}

// MARK: - Tab Content
private extension MainAppView {
    var selectedTabBinding: Binding<Int> {
        Binding(
            get: { selectedTab.rawValue },
            set: { newValue in
                if let tab = Tab(rawValue: newValue) {
                    selectedTab = tab
                }
            }
        )
    }

    @ViewBuilder
    func tabContent(for tab: Tab) -> some View {
        switch tab {
        case .art:
            NavigationStack {
                CategorySelectionView(selectedTab: selectedTabBinding)
            }
        case .gallery:
            NavigationStack {
                GalleryView(selectedTab: selectedTabBinding)
            }
        case .stories:
            NavigationStack {
                BedtimeStoriesLibraryView(selectedTab: selectedTabBinding)
            }
        case .books:
            NavigationStack {
                BooksView()
            }
        case .folders:
            NavigationStack {
                FolderView(selectedTab: selectedTabBinding)
            }
        }
    }
}


// MARK: - Appearance Configuration
private extension MainAppView {
    static func configureAppearance() {
        // Configure native tab bar appearance for both iPhone and iPad
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(AppColors.backgroundLight)

        // Configure stacked layout (iPhone and iPad bottom tab bar)
        tabAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppColors.textSecondary)
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.textSecondary),
            .font: UIFont.systemFont(ofSize: 12, weight: .medium)
        ]

        tabAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppColors.primaryBlue)
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.primaryBlue),
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold)
        ]

        // Also configure compact layout for iPad when in split view
        tabAppearance.compactInlineLayoutAppearance.normal.iconColor = UIColor(AppColors.textSecondary)
        tabAppearance.compactInlineLayoutAppearance.selected.iconColor = UIColor(AppColors.primaryBlue)

        // Apply to all tab bar states
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // Configure navigation bar appearance for large titles
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()

        if let descriptor = UIFont.systemFont(ofSize: 34, weight: .bold).fontDescriptor.withDesign(.rounded) {
            navAppearance.largeTitleTextAttributes = [
                .font: UIFont(descriptor: descriptor, size: 34)
            ]
        }

        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.textPrimary),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance

        // Configure iPad-specific navigation bar layout margins
        if UIDevice.current.userInterfaceIdiom == .pad {
            // Set layout margins for navigation bar (titles and toolbar items)
            UINavigationBar.appearance().layoutMargins = UIEdgeInsets(
                top: 0,
                left: 76,  // Increased padding for iPad titles
                bottom: 0,
                right: 76  // Increased padding for iPad titles
            )
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
