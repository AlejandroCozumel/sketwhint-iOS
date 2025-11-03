import SwiftUI

struct MainAppView: View {
    @State private var selectedTab: Tab = .art
    @StateObject private var tokenManager = TokenBalanceManager.shared
    @StateObject private var localization = LocalizationManager.shared

    init() {
        Self.configureAppearance()
    }

    var body: some View {
        tabContainers
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .safeAreaInset(edge: .bottom) {
                MainTabBar(selectedTab: $selectedTab)
            }
            .tint(AppColors.primaryBlue)
        .safeAreaInset(edge: .top) {
            NetworkStatusBanner()
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            // Silent token refresh when navigating to Art tab (tab 0)
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
        case folders
        case profiles

        var title: String {
            switch self {
            case .art: return "nav.art".localized
            case .gallery: return "nav.gallery".localized
            case .stories: return "nav.stories".localized
            case .folders: return "nav.folders".localized
            case .profiles: return "nav.profiles".localized
            }
        }

        var systemImage: String {
            switch self {
            case .art: return "paintbrush.fill"
            case .gallery: return "photo.fill"
            case .stories: return "moon.stars.fill"
            case .folders: return "folder.fill"
            case .profiles: return "person.2.fill"
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
    var tabContainers: some View {
        ZStack {
            ForEach(Tab.allCases, id: \.rawValue) { tab in
                tabContent(for: tab)
                    .opacity(selectedTab == tab ? 1 : 0)
                    .zIndex(selectedTab == tab ? 1 : 0)
                    .allowsHitTesting(selectedTab == tab)
            }
        }
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
        case .folders:
            NavigationStack {
                FolderView(selectedTab: selectedTabBinding)
            }
        case .profiles:
            NavigationStack {
                ProfilesView()
            }
        }
    }
}

// MARK: - Custom Tab Bar
private struct MainTabBar: View {
    @Binding var selectedTab: MainAppView.Tab

    private let tabItems = MainAppView.Tab.allCases

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(AppColors.borderLight)

            HStack(spacing: 0) {
                ForEach(tabItems, id: \.rawValue) { tab in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    }) {
                        VStack(spacing: AppSpacing.xs) {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 20, weight: .semibold))

                            Text(tab.title)
                                .font(AppTypography.captionLarge)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .foregroundColor(selectedTab == tab ? AppColors.primaryBlue : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .padding(.horizontal, AppSpacing.xs)
                        .background(
                            Group {
                                if selectedTab == tab {
                                    RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                                        .fill(AppColors.primaryBlue.opacity(0.12))
                                } else {
                                    Color.clear
                                }
                            }
                        )
                        .contentShape(Rectangle())
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .background(Color.white)
        }
        .background(
            Color.white
                .ignoresSafeArea(edges: .bottom)
        )
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: -4)
    }
}

// MARK: - Appearance Configuration
private extension MainAppView {
    static func configureAppearance() {
        // Configure tab bar appearance globally before the TabView renders
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(AppColors.backgroundLight)

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
