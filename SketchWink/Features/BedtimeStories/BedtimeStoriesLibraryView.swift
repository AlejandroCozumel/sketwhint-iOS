import SwiftUI
import AVFoundation

struct BedtimeStoriesLibraryView: View {
    @Binding var selectedTab: Int
    @ObservedObject private var service = BedtimeStoriesService.shared
    @StateObject private var profileService = ProfileService.shared
    @StateObject private var tokenManager = TokenBalanceManager.shared
    @StateObject private var localization = LocalizationManager.shared

    @State private var selectedStory: BedtimeStory?
    @State private var showCreateStory = false
    @State private var isLoadingStoryDetails = false
    @State private var showSubscriptionPlans = false
    @State private var showingProfileMenu = false
    @State private var showPainting = false
    @State private var showSettings = false

    // Filters
    @State private var showFavoritesOnly = false
    @State private var selectedTheme: String?
    @State private var selectedProfileFilter: String? = nil
    @State private var searchText = ""

    // Local stories array (managed by view, not service)
    @State private var stories: [BedtimeStory] = []

    // Pagination
    @State private var currentPage = 1
    @State private var isLoading = false
    @State private var hasMorePages = true
    @State private var isRefreshing = false

    // Computed property to check if any filters are active
    private var hasActiveFilters: Bool {
        showFavoritesOnly || selectedTheme != nil || selectedProfileFilter != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            if UIDevice.current.userInterfaceIdiom == .pad {
                iPadTabHeader(
                    profileService: profileService,
                    tokenManager: tokenManager,
                    title: "stories.title".localized,
                    onMenuTap: { showingProfileMenu = true },
                    onCreditsTap: { /* TODO: Show purchase credits modal */ },
                    onUpgradeTap: { showSubscriptionPlans = true }
                ) {
                    Button {
                        showCreateStory = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: "#6366F1"))
                            .frame(width: 36, height: 36)
                    }
                    .childSafeTouchTarget()
                }
            }

            // Filter chips - show if stories exist OR any filters are active
            if !stories.isEmpty || hasActiveFilters {
                filterChipsView
            }

            // Stories grid or empty state
            if isLoading && stories.isEmpty {
                loadingView
            } else if stories.isEmpty {
                emptyStateView
            } else {
                storiesGridView
            }
        }
        .iPadContentPadding() // Apply to entire view including title
        .background(AppColors.backgroundLight)
        .navigationTitle(UIDevice.current.userInterfaceIdiom == .pad ? "nav.stories".localized : "stories.title".localized)
        .navigationBarTitleDisplayMode(UIDevice.current.userInterfaceIdiom == .pad ? .inline : .large)
        .toolbar {
            if UIDevice.current.userInterfaceIdiom != .pad {
                SimpleToolbarContent(
                    profileService: profileService,
                    onMenuTap: { showingProfileMenu = true }
                )

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateStory = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: "#6366F1"))
                            .frame(width: 36, height: 36)
                    }
                }
            }
        }
        .dismissableFullScreenCover(isPresented: $showCreateStory) {
            NavigationView {
                BedtimeStoriesCreateView(category: service.category)
            }
        }
        .dismissableFullScreenCover(item: $selectedStory) { story in
            StoryPlayerView(story: story) { deletedStoryId in
                stories.removeAll { $0.id == deletedStoryId }
                selectedStory = nil
            }
        }
        .dismissableFullScreenCover(isPresented: $showSubscriptionPlans) {
            SubscriptionPlansView()
        }
        .dismissableFullScreenCover(isPresented: $showingProfileMenu) {
            ProfileMenuSheet(
                selectedTab: $selectedTab,
                showPainting: $showPainting,
                showSettings: $showSettings
            )
        }
        .dismissableFullScreenCover(isPresented: $showPainting) {
            NavigationView {
                PaintingView()
            }
        }
        .dismissableFullScreenCover(isPresented: $showSettings) {
            SettingsView()
        }
        .task {
            await loadInitialData()
        }
        .onChange(of: localization.currentLanguage) { oldValue, newValue in
            Task {
                await reloadTranslatedContent()
            }
        }
    }

    // MARK: - Filter Chips
    private var filterChipsView: some View {
        UnifiedFilterChips(
            config: .bedtimeStories(
                profileService: profileService,
                showFavoritesOnly: showFavoritesOnly,
                selectedProfileFilter: selectedProfileFilter,
                selectedTheme: selectedTheme,
                availableThemes: themeFilterCategories,
                onFavoritesToggle: { favoritesOnly in
                    showFavoritesOnly = favoritesOnly
                    applyFilters()
                },
                onProfileFilterChange: { profileId in
                    selectedProfileFilter = profileId
                    applyFilters()
                },
                onThemeChange: { themeId in
                    selectedTheme = themeId
                    applyFilters()
                }
            )
        )
    }

    private var themeFilterCategories: [FilterCategory] {
        service.themes.map { theme in
            FilterCategory(
                id: theme.id,
                name: theme.name,
                icon: "moon.stars.fill",
                color: theme.color.map { Color(hex: $0) } ?? AppColors.primaryIndigo
            )
        }
    }

    // MARK: - Stories Grid
    private var storiesGridView: some View {
        ScrollView {
            LazyVGrid(columns: GridLayouts.categoryGrid, alignment: .leading, spacing: AppSpacing.grid.itemSpacing) {
                ForEach(stories) { story in
                    StoryCard(story: story) {
                        Task {
                            await openStoryPlayer(storyId: story.id)
                        }
                    } onFavorite: {
                        Task {
                            await toggleFavorite(story)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // Load more indicator (only if not refreshing)
                if hasMorePages && !isLoading && !isRefreshing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .onAppear {
                            Task {
                                await loadMoreStories()
                            }
                        }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.xl)
        }
        .refreshable {
            await refreshStories()
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color(hex: "#6366F1"))

            Text("stories.loading".localized)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: hasActiveFilters ? "tray.fill" : "moon.stars")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#6366F1").opacity(0.6))

            VStack(spacing: AppSpacing.sm) {
                Text(emptyStateTitle)
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(emptyStateMessage)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            Button {
                if hasActiveFilters {
                    clearAllFilters()
                } else {
                    showCreateStory = true
                }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: hasActiveFilters ? "xmark.circle" : "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))

                    Text(hasActiveFilters ? "stories.clear.filters".localized : "stories.create.story".localized)
                        .font(AppTypography.titleMedium)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
                .background(Color(hex: "#6366F1"))
                .clipShape(Capsule())
            }
            .childSafeTouchTarget()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, AppSpacing.xl)
    }

    // MARK: - Empty State Helpers
    private var emptyStateTitle: String {
        let themeName = selectedTheme.flatMap { id in
            service.themes.first(where: { $0.id == id })?.name
        }
        let profileName = selectedProfileName

        switch (showFavoritesOnly, themeName, profileName) {
        case (true, let theme?, let profile?):
            return String(format: "stories.empty.favorite.theme.profile".localized, theme, profile)
        case (true, let theme?, nil):
            return String(format: "stories.empty.favorite.theme".localized, theme)
        case (true, nil, let profile?):
            return String(format: "stories.empty.favorite.profile".localized, profile)
        case (true, nil, nil):
            return "stories.empty.favorite".localized
        case (false, let theme?, let profile?):
            return String(format: "stories.empty.theme.profile".localized, theme, profile)
        case (false, let theme?, nil):
            return String(format: "stories.empty.theme".localized, theme)
        case (false, nil, let profile?):
            return String(format: "stories.empty.profile".localized, profile)
        default:
            return "stories.empty.title".localized
        }
    }

    private var emptyStateMessage: String {
        if hasActiveFilters {
            return "stories.empty.filters.message".localized
        } else {
            return "stories.empty.message".localized
        }
    }

    // MARK: - Data Methods
    private func loadInitialData() async {
        // Load themes for filter categories
        _ = try? await service.getThemes()
        await loadStories()
    }

    /// Reload only translated content when language changes
    private func reloadTranslatedContent() async {
        do {
            // Reload themes to get updated translations for filter chips
            _ = try await service.getThemes()

            #if DEBUG
            print("🌐 BedtimeStoriesLibraryView: Reloaded translated themes - \(service.themes.count) themes")
            #endif
        } catch {
            #if DEBUG
            print("❌ BedtimeStoriesLibraryView: Error reloading themes - \(error.localizedDescription)")
            #endif
        }
    }

    private func loadStories() async {
        guard !isLoading else { return } // Prevent multiple simultaneous loads

        isLoading = true
        currentPage = 1

        do {
            let response = try await service.getStories(
                page: currentPage,
                favorites: showFavoritesOnly ? true : nil,
                theme: selectedTheme,
                filterByProfile: selectedProfileFilter
            )

            await MainActor.run {
                stories = response.stories
                hasMorePages = response.pagination.page < response.pagination.totalPages
            }
        } catch {
            print("❌ Error loading stories: \(error)")
        }

        isLoading = false
    }

    private func loadMoreStories() async {
        guard !isLoading && hasMorePages else { return }

        isLoading = true
        currentPage += 1

        do {
            let response = try await service.getStories(
                page: currentPage,
                favorites: showFavoritesOnly ? true : nil,
                theme: selectedTheme,
                filterByProfile: selectedProfileFilter
            )

            await MainActor.run {
                stories.append(contentsOf: response.stories)
                hasMorePages = response.pagination.page < response.pagination.totalPages
            }
        } catch {
            await MainActor.run {
                currentPage -= 1 // Revert page increment on error
            }
            print("❌ Error loading more stories: \(error)")
        }

        isLoading = false
    }

    private func refreshStories() async {
        // Set refreshing flag to prevent infinite scroll during refresh
        isRefreshing = true

        // Reset state before loading
        currentPage = 1

        do {
            let response = try await service.getStories(
                page: currentPage,
                favorites: showFavoritesOnly ? true : nil,
                theme: selectedTheme,
                filterByProfile: selectedProfileFilter
            )

            await MainActor.run {
                stories = response.stories
                hasMorePages = response.pagination.page < response.pagination.totalPages
                isRefreshing = false
            }
        } catch {
            print("❌ Error refreshing stories: \(error)")
            await MainActor.run {
                isRefreshing = false
            }
        }
    }

    private func applyFilters() {
        Task {
            await loadStories()
        }
    }

    private func clearAllFilters() {
        showFavoritesOnly = false
        selectedTheme = nil
        selectedProfileFilter = nil
        applyFilters()
    }

    private var selectedProfileName: String? {
        guard let profileId = selectedProfileFilter else { return nil }
        return profileService.availableProfiles.first(where: { $0.id == profileId })?.name
    }

    private func openStoryPlayer(storyId: String) async {
        isLoadingStoryDetails = true

        do {
            #if DEBUG
            print("🎯 BedtimeStoriesLibraryView: Fetching full story details for ID: \(storyId)")
            #endif

            let fullStory = try await service.getStory(id: storyId)

            #if DEBUG
            print("✅ BedtimeStoriesLibraryView: Full story loaded")
            print("   - Title: \(fullStory.title)")
            print("   - Has storyText: \(fullStory.storyText != nil)")
            if let storyText = fullStory.storyText {
                print("   - StoryText length: \(storyText.count) chars")
            }
            print("   - Has wordTimestamps: \(fullStory.wordTimestamps != nil)")
            if let timestamps = fullStory.wordTimestamps {
                print("   - WordTimestamps length: \(timestamps.count) chars")
            }
            #endif

            await MainActor.run {
                selectedStory = fullStory
                isLoadingStoryDetails = false
            }
        } catch {
            print("❌ Error loading story details: \(error)")
            isLoadingStoryDetails = false
        }
    }

    private func toggleFavorite(_ story: BedtimeStory) async {
        do {
            let newFavoriteStatus = try await service.toggleFavorite(id: story.id)

            await MainActor.run {
                // Update local story state
                if let index = stories.firstIndex(where: { $0.id == story.id }) {
                    stories[index].isFavorite = newFavoriteStatus

                    // Remove from list if viewing favorites only and unfavorited
                    if showFavoritesOnly && !newFavoriteStatus {
                        _ = withAnimation {
                            stories.remove(at: index)
                        }
                    }
                }
            }
        } catch {
            print("❌ Error toggling favorite: \(error)")
        }
    }
}

// MARK: - Story Card
struct StoryCard: View {
    let story: BedtimeStory
    let onTap: () -> Void
    let onFavorite: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Image with favorite button overlay
                ZStack {
                    OptimizedAsyncImage(
                        url: URL(string: story.imageUrl),
                        thumbnailSize: 240,
                        quality: 0.7,
                        content: { optimizedImage in
                            optimizedImage
                                .resizable()
                                .scaledToFill()
                        },
                        placeholder: {
                            storyLoadingPlaceholder
                        },
                        failure: {
                            storyFailurePlaceholder
                        }
                    )
                    .frame(height: 120)
                    .clipped()

                    // Favorite button overlay (top-right)
                    VStack {
                        HStack {
                            Spacer()
                            AnimatedFavoriteButton(
                                isFavorite: story.isFavorite,
                                onToggle: onFavorite
                            )
                            .padding(AppSpacing.xs)
                        }
                        Spacer()
                    }
                }
                .frame(height: 120)

                // Content - flexible to match row height
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(story.title)
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 0)

                    if let theme = story.theme {
                        Text(theme)
                            .font(AppTypography.captionLarge)
                            .foregroundColor(AppColors.primaryIndigo)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text(formatDuration(story.duration))
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.md)
            }
            .frame(maxWidth: .infinity)
            .background(AppColors.backgroundLight)
            .cornerRadius(AppSizing.cornerRadius.lg)
            .shadow(
                color: Color.black.opacity(0.1),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(PlainButtonStyle())
}

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d min", minutes, remainingSeconds)
    }

    private var storyLoadingPlaceholder: some View {
        Rectangle()
            .fill(AppColors.surfaceLight)
            .overlay(
                ProgressView()
                    .tint(AppColors.primaryIndigo)
            )
            .shimmer()
    }

    private var storyFailurePlaceholder: some View {
        Rectangle()
            .fill(AppColors.primaryIndigo.opacity(0.2))
            .overlay(
                Image(systemName: "moon.stars")
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.primaryIndigo)
            )
    }
}

// MARK: - Filter Chip (using shared component from UnifiedFilterChips.swift)
