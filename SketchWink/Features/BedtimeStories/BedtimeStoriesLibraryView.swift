import SwiftUI
import AVFoundation

struct BedtimeStoriesLibraryView: View {
    @Binding var selectedTab: Int
    @StateObject private var service = BedtimeStoriesService.shared
    @StateObject private var profileService = ProfileService.shared
    @StateObject private var tokenManager = TokenBalanceManager.shared

    @State private var selectedStory: BedtimeStory?
    @State private var showCreateStory = false
    @State private var showSubscriptionPlans = false
    @State private var isLoadingStoryDetails = false

    // Filters
    @State private var showFavoritesOnly = false
    @State private var selectedTheme: String?
    @State private var searchText = ""

    // Pagination
    @State private var currentPage = 1
    @State private var isLoading = false
    @State private var hasMorePages = true

    var body: some View {
        VStack(spacing: 0) {
            // Filter chips
            if !service.stories.isEmpty || showFavoritesOnly {
                filterChipsView
            }

            // Stories grid or empty state
            if isLoading && service.stories.isEmpty {
                loadingView
            } else if service.stories.isEmpty {
                emptyStateView
            } else {
                storiesGridView
            }
        }
        .navigationTitle("Bedtime Stories")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                ProfileMenuButton(selectedTab: $selectedTab)
            }

            // Right Plus Button
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateStory = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#6366F1"))
                }
            }
        }
        .sheet(isPresented: $showCreateStory) {
            NavigationView {
                BedtimeStoriesCreateView()
            }
        }
        .sheet(item: $selectedStory) { story in
            StoryPlayerView(story: story)
        }
        .sheet(isPresented: $showSubscriptionPlans) {
            SubscriptionPlansView()
        }
        .task {
            await loadStories()
        }
    }

    // MARK: - Filter Chips
    private var filterChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                // Favorites filter
                FilterChip(
                    title: "Favorites",
                    icon: "heart.fill",
                    isSelected: showFavoritesOnly
                ) {
                    showFavoritesOnly.toggle()
                    applyFilters()
                }

                // Theme filters (if available)
                ForEach(Array(Set(service.stories.compactMap { $0.theme })), id: \.self) { theme in
                    FilterChip(
                        title: theme,
                        icon: "book.fill",
                        isSelected: selectedTheme == theme
                    ) {
                        if selectedTheme == theme {
                            selectedTheme = nil
                        } else {
                            selectedTheme = theme
                        }
                        applyFilters()
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
        }
    }

    // MARK: - Stories Grid
    private var storiesGridView: some View {
        ScrollView {
            LazyVGrid(columns: GridLayouts.categoryGrid, spacing: AppSpacing.grid.itemSpacing) {
                ForEach(service.stories) { story in
                    StoryCard(story: story) {
                        Task {
                            await openStoryPlayer(storyId: story.id)
                        }
                    } onFavorite: {
                        Task {
                            await toggleFavorite(story)
                        }
                    }
                }

                // Load more indicator
                if hasMorePages && !isLoading {
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

            Text("Loading stories...")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: showFavoritesOnly ? "heart.slash" : "moon.stars")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#6366F1").opacity(0.6))

            VStack(spacing: AppSpacing.sm) {
                Text(showFavoritesOnly ? "No Favorite Stories" : "No Bedtime Stories Yet")
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(showFavoritesOnly ? "Tap the heart icon to save your favorites" : "Create your first bedtime story with AI")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }

            Button {
                if showFavoritesOnly {
                    showFavoritesOnly = false
                    applyFilters()
                } else {
                    showCreateStory = true
                }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: showFavoritesOnly ? "xmark.circle" : "plus.circle.fill")
                        .font(.system(size: 16, weight: .semibold))

                    Text(showFavoritesOnly ? "Clear Filters" : "Create Story")
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

    // MARK: - Data Methods
    private func loadStories() async {
        guard !isLoading else { return } // Prevent multiple simultaneous loads

        isLoading = true
        currentPage = 1
        hasMorePages = true

        do {
            let response = try await service.getStories(
                page: currentPage,
                favorites: showFavoritesOnly ? true : nil,
                theme: selectedTheme
            )
            hasMorePages = response.pagination.page < response.pagination.totalPages
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
                theme: selectedTheme
            )

            await MainActor.run {
                service.stories.append(contentsOf: response.stories)
                hasMorePages = response.pagination.page < response.pagination.totalPages
            }
        } catch {
            print("❌ Error loading more stories: \(error)")
        }

        isLoading = false
    }

    private func refreshStories() async {
        await loadStories()
    }

    private func applyFilters() {
        Task {
            await loadStories()
        }
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
            _ = try await service.toggleFavorite(id: story.id)

            // Remove from list if viewing favorites only and unfavorited
            if showFavoritesOnly, let index = service.stories.firstIndex(where: { $0.id == story.id && !$0.isFavorite }) {
                withAnimation {
                    service.stories.remove(at: index)
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
                    AsyncImage(url: URL(string: story.imageUrl)) { imagePhase in
                        switch imagePhase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 120)
                                .clipped()
                        case .failure(_):
                            Rectangle()
                                .fill(Color(hex: "#6366F1").opacity(0.2))
                                .frame(height: 120)
                                .overlay(
                                    Image(systemName: "moon.stars")
                                        .font(.system(size: 32))
                                        .foregroundColor(Color(hex: "#6366F1"))
                                )
                        case .empty:
                            Rectangle()
                                .fill(AppColors.surfaceLight)
                                .frame(height: 120)
                                .shimmer()
                        @unknown default:
                            EmptyView()
                        }
                    }

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

                // Content
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(story.title)
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let theme = story.theme {
                        Text(theme)
                            .font(AppTypography.captionLarge)
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Label(formatDuration(story.duration), systemImage: "clock")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.md)
            }
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
}

// MARK: - Filter Chip (using shared component from UnifiedFilterChips.swift)
