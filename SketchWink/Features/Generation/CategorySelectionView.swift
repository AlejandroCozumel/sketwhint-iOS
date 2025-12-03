import SwiftUI

struct CategorySelectionView: View {
    @StateObject private var generationService = GenerationService.shared
    @StateObject private var profileService = ProfileService.shared
    @StateObject private var tokenManager = TokenBalanceManager.shared
    @StateObject private var localization = LocalizationManager.shared
    @ObservedObject private var bedtimeStoriesService = BedtimeStoriesService.shared
    @Binding var selectedTab: Int
    @State private var categories: [CategoryWithOptions] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var showingError = false
    @State private var selectedCategory: CategoryWithOptions?
    @State private var showingProfileMenu = false
    @State private var showPainting = false
    @State private var showSettings = false
    @State private var showSubscriptionPlans = false
    @State private var showBedtimeStories = false
    @State private var showCreateBook = false
    
    
    var body: some View {
        VStack(spacing: 0) {
            if UIDevice.current.userInterfaceIdiom == .pad {
                iPadTabHeader(
                    profileService: profileService,
                    tokenManager: tokenManager,
                    title: "generation.title".localized,
                    onMenuTap: { showingProfileMenu = true },
                    onCreditsTap: { /* TODO: Show purchase credits modal */ },
                    onUpgradeTap: { showSubscriptionPlans = true }
                )
            }

            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    if isLoading {
                        loadingView
                    } else {
                        // Categories Grid
                        categoriesGridView

                        // Bedtime Stories Section
                        bedtimeStoriesSection

                        // Books Section
                        booksSection
                    }
                }
                .pageMargins()
                .padding(.vertical, AppSpacing.sectionSpacing)
            }
        }
        .iPadContentPadding()
        .background(AppColors.backgroundLight)
        .navigationTitle(UIDevice.current.userInterfaceIdiom == .pad ? "Art" : "generation.title".localized)
        .navigationBarTitleDisplayMode(UIDevice.current.userInterfaceIdiom == .pad ? .inline : .large)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            // On iPhone: show toolbar in navigation bar
            // On iPad: navigation bar stays clean
            if UIDevice.current.userInterfaceIdiom != .pad {
                AppToolbarContent(
                    profileService: profileService,
                    tokenManager: tokenManager,
                    onMenuTap: { showingProfileMenu = true },
                    onCreditsTap: { /* TODO: Show purchase credits modal */ },
                    onUpgradeTap: { showSubscriptionPlans = true }
                )
            }
        }
        .dismissableFullScreenCover(isPresented: $showingProfileMenu) {
            ProfileMenuSheet(
                selectedTab: $selectedTab,
                showPainting: $showPainting,
                showSettings: $showSettings
            )
        }
        .dismissableFullScreenCover(isPresented: $showSubscriptionPlans) {
            SubscriptionPlansView()
        }
        .dismissableFullScreenCover(isPresented: $showPainting) {
            NavigationView {
                PaintingView()
            }
        }
        .dismissableFullScreenCover(isPresented: $showSettings) {
            SettingsView()
        }
        .dismissableFullScreenCover(isPresented: $showBedtimeStories) {
            NavigationView {
                BedtimeStoriesCreateView(category: bedtimeStoriesService.category)
            }
        }
        .dismissableFullScreenCover(isPresented: $showCreateBook) {
            StoryDraftCreationView(
                productCategory: storyBooksCategory,
                onDismiss: {
                    showCreateBook = false
                },
                onDraftCreated: { draft in
                    showCreateBook = false
                    // Navigate to Books tab to see the created book
                    selectedTab = 3
                }
            )
        }
        .task {
            await tokenManager.initialize()
            await loadCategories()
        }
        .alert("common.error".localized, isPresented: $showingError) {
            Button("common.ok".localized) { }
        } message: {
            Text(error?.localizedDescription ?? "error.generic".localized)
        }
        .dismissableFullScreenCover(item: $selectedCategory) { category in
            GenerationView(
                preselectedCategory: category,
                selectedTab: $selectedTab,
                onDismiss: {
                    selectedCategory = nil
                }
            )
            .onAppear {
                #if DEBUG
                print("🎯 CategorySelection: Sheet opened with category: \(category.category.name)")
                print("🎯 CategorySelection: Options count: \(category.options.count)")
                #endif
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: AppSpacing.sectionSpacing) {
            // Categories skeleton
            skeletonCategoriesView

            // Bedtime Stories skeleton
            skeletonBedtimeStoriesView

            // Books skeleton
            skeletonBooksView
        }
    }

    // MARK: - Skeleton Categories
    private var skeletonCategoriesView: some View {
        VStack(alignment: .center, spacing: AppSpacing.md) {
            // Section title skeleton
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.textSecondary.opacity(0.3))
                .frame(width: 180, height: 24)
                .shimmer()
                .padding(.bottom, 10)

            // Grid of skeleton cards
            LazyVGrid(columns: GridLayouts.categoryGrid, spacing: AppSpacing.grid.itemSpacing) {
                ForEach(0..<6, id: \.self) { _ in
                    SkeletonCategoryCard()
                }
            }
        }
    }

    // MARK: - Skeleton Bedtime Stories
    private var skeletonBedtimeStoriesView: some View {
        VStack(alignment: .center, spacing: AppSpacing.md) {
            // Section title skeleton
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.textSecondary.opacity(0.3))
                .frame(width: 180, height: 24)
                .shimmer()
                .padding(.bottom, 10)

            // Bedtime story card skeleton
            SkeletonBedtimeStoryCard()
        }
    }

    // MARK: - Skeleton Books
    private var skeletonBooksView: some View {
        VStack(alignment: .center, spacing: AppSpacing.md) {
            // Section title skeleton
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.textSecondary.opacity(0.3))
                .frame(width: 120, height: 24)
                .shimmer()
                .padding(.bottom, 10)

            // Books card skeleton
            SkeletonBedtimeStoryCard() // Same style as bedtime stories
        }
    }
    
    // MARK: - Categories Grid
    private var categoriesGridView: some View {
        VStack(alignment: .center, spacing: AppSpacing.md) {
            Text("generation.creative.categories".localized)
                .font(AppTypography.categoryTitle)
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 10)

            LazyVGrid(columns: GridLayouts.categoryGrid, spacing: AppSpacing.grid.itemSpacing) {
                ForEach(categories) { category in
                    CategoryCard(category: category.category) {
                        #if DEBUG
                        print("🎯 CategorySelection: Selected \(category.category.name) with \(category.options.count) options")
                        for option in category.options {
                            print("   - \(option.name)")
                        }
                        #endif
                        selectedCategory = category
                    }
                }
            }
        }
    }
    
    // MARK: - Bedtime Stories Section
    private var bedtimeStoriesSection: some View {
        VStack(alignment: .center, spacing: AppSpacing.md) {
            Text(bedtimeStoriesService.category?.name ?? String(localized: "stories.title"))
                .font(AppTypography.categoryTitle)
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 10)

            BedtimeStoryFeatureCard(category: bedtimeStoriesService.category) {
                showBedtimeStories = true
            }
        }
    }

    // MARK: - Books Section
    private var booksSection: some View {
        VStack(alignment: .center, spacing: AppSpacing.md) {
            Text("Story Books")
                .font(AppTypography.categoryTitle)
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 10)

            BooksFeatureCard {
                // Open book creation sheet
                showCreateBook = true
            }
        }
    }

    // Story Books ProductCategory for creation
    private var storyBooksCategory: ProductCategory {
        ProductCategory(
            id: "story_books",
            name: "Story Books",
            description: "Create personalized story books",
            icon: "📖",
            imageUrl: nil,
            color: "#6366F1",
            tokenCost: 4,
            multipleOptions: true,
            maxOptionsCount: 10,
            isActive: true,
            isDefault: false,
            sortOrder: 0,
            createdAt: "",
            updatedAt: "",
            productType: "book",
            draftEndpoint: "/api/stories/drafts",
            generateEndpoint: "/api/books/{draftId}/generate-images",
            browseEndpoint: "/api/books",
            requiresStoryFlow: true,
            supportedFormats: ["pdf", "epub"],
            features: ["illustrations", "chapters", "custom_stories"],
            estimatedDuration: "5-10 minutes"
        )
    }

    // MARK: - Methods

    private func loadCategories() async {
        isLoading = true

        do {
            // Load regular categories (backend now excludes books automatically)
            categories = try await generationService.getCategoriesWithOptions()

            // Load bedtime stories themes and category info
            _ = try await bedtimeStoriesService.getThemes()

            #if DEBUG
            print("🎨 CategorySelection: Loaded \(categories.count) visual art categories")
            print("🌙 CategorySelection: Loaded \(bedtimeStoriesService.themes.count) bedtime story themes")
            #endif

        } catch {
            self.error = error
            showingError = true
        }

        isLoading = false
    }
}

// MARK: - Bedtime Story Feature Card
struct BedtimeStoryFeatureCard: View {
    let category: BedtimeStoryCategory?
    let action: () -> Void
    
    private var categoryColor: Color {
        if let colorHex = category?.color {
            return Color(hex: colorHex)
        }
        return AppColors.primaryIndigo
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Top half - Image
                if let imageUrl = category?.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { imagePhase in
                        switch imagePhase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .frame(height: 200, alignment: .top)
                                .clipped()
                        case .failure(_):
                            Rectangle()
                                .fill(categoryColor.opacity(0.2))
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                        case .empty:
                            Rectangle()
                                .fill(AppColors.textSecondary.opacity(0.3))
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                                .shimmer()
                        @unknown default:
                            Rectangle()
                                .fill(categoryColor.opacity(0.2))
                                .frame(maxWidth: .infinity)
                                .frame(height: 200)
                        }
                    }
                } else {
                    Rectangle()
                        .fill(categoryColor.opacity(0.2))
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                }

                // Bottom half - Text
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(category?.name ?? String(localized: "stories.title"))
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    Text(category?.description ?? String(localized: "stories.description"))
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    // Additional info row
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "circle.inset.filled")
                                .foregroundColor(AppColors.warningOrange)
                                .font(.system(size: 12))
                            Text("5-10 tokens")
                                .captionLarge()
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "waveform")
                                .foregroundColor(AppColors.primaryBlue)
                                .font(.system(size: 12))
                            Text("Audio Story")
                                .captionLarge()
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .background(categoryColor.opacity(0.08))
            .cornerRadius(AppSizing.cornerRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                    .stroke(categoryColor.opacity(0.3), lineWidth: 1)
            )
            .shadow(
                color: categoryColor.opacity(0.3),
                radius: 10,
                x: 0,
                y: 10
            )
        }
        .childSafeTouchTarget()
    }
}

// MARK: - Category Card
struct CategoryCard: View {
    let category: GenerationCategory
    let action: () -> Void
    
    private var categoryColor: Color {
        if let colorHex = category.color {
            return Color(hex: colorHex)
        }
        
        // Fallback to hardcoded colors if backend doesn't provide color
        switch category.id {
        case "coloring_pages": return AppColors.coloringPagesColor
        case "stickers": return AppColors.stickersColor
        case "wallpapers": return AppColors.wallpapersColor
        case "mandalas": return AppColors.mandalasColor
        default: return AppColors.primaryBlue
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Top half - Image (no padding, rounded top corners only)
                if let imageUrl = category.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { imagePhase in
                        switch imagePhase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .frame(height: 200, alignment: .top)
                                .clipped()
                        case .failure(_):
                            Rectangle()
                                .fill(categoryColor.opacity(0.2))
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .frame(height: 200)
                                .overlay(
                                    Text(category.icon ?? "🎨")
                                        .font(.system(size: 40))
                                )
                        case .empty:
                            // Skeleton loading state
                            Rectangle()
                                .fill(AppColors.textSecondary.opacity(0.3))
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .frame(height: 200)
                                .shimmer()
                        @unknown default:
                            Rectangle()
                                .fill(categoryColor.opacity(0.2))
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .frame(height: 200)
                                .overlay(
                                    Text(category.icon ?? "🎨")
                                        .font(.system(size: 40))
                                )
                        }
                    }
                } else {
                    Rectangle()
                        .fill(categoryColor.opacity(0.2))
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .frame(height: 200)
                        .overlay(
                            Text(category.icon ?? "🎨")
                                .font(.system(size: 40))
                        )
                }

                // Bottom half - Text with padding
                VStack(spacing: AppSpacing.xs) {
                    Text(category.name)
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(category.description)
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity)
                .frame(height: 100)
            }
            .frame(height: 300)
            .frame(minWidth: 0, maxWidth: .infinity)
            .background(categoryColor.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                    .stroke(categoryColor.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg))
            .shadow(
                color: categoryColor.opacity(0.3),
                radius: 10,
                x: 0,
                y: 10
            )
        }
        .childSafeTouchTarget()
    }
}

// MARK: - Skeleton Category Card
struct SkeletonCategoryCard: View {
    var body: some View {
        VStack(spacing: 0) {
            // Top half - Image skeleton (100pt only, with top corners rounded)
            Rectangle()
                .fill(AppColors.textSecondary.opacity(0.3))
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .shimmer()

            // Bottom half - Text skeleton
            VStack(spacing: AppSpacing.xs) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColors.textSecondary.opacity(0.3))
                    .frame(width: 100, height: 16)
                    .shimmer()

                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColors.textSecondary.opacity(0.2))
                    .frame(width: 120, height: 12)
                    .shimmer()
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity)
            .frame(height: 100)
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                .fill(AppColors.textSecondary.opacity(0.1))
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg))
    }
}

// MARK: - Skeleton Bedtime Story Card
struct SkeletonBedtimeStoryCard: View {
    var body: some View {
        VStack(spacing: 0) {
            // Top half - Image skeleton
            Rectangle()
                .fill(AppColors.textSecondary.opacity(0.3))
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .shimmer()

            // Bottom half - Content skeleton
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColors.textSecondary.opacity(0.3))
                    .frame(width: 150, height: 18)
                    .shimmer()

                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColors.textSecondary.opacity(0.2))
                    .frame(height: 14)
                    .shimmer()

                Spacer()

                HStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColors.textSecondary.opacity(0.2))
                        .frame(width: 80, height: 12)
                        .shimmer()

                    Spacer()

                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColors.textSecondary.opacity(0.2))
                        .frame(width: 90, height: 12)
                        .shimmer()
                }
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .background(AppColors.textSecondary.opacity(0.1))
        .cornerRadius(AppSizing.cornerRadius.lg)
    }
}

// MARK: - Books Feature Card
struct BooksFeatureCard: View {
    let action: () -> Void

    private var categoryColor: Color {
        Color(hex: "#6366F1") // Indigo-500 for books
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Top half - Image placeholder with icon
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [categoryColor.opacity(0.6), categoryColor.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .overlay(
                        Text("📖")
                            .font(.system(size: 80))
                    )

                // Bottom half - Text
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Story Books")
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    Text("Create custom illustrated story books with AI")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    // Additional info row
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(AppColors.warningOrange)
                                .font(.system(size: 12))
                            Text("4+ tokens")
                                .captionLarge()
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "book.pages.fill")
                                .foregroundColor(categoryColor)
                                .font(.system(size: 12))
                            Text("Illustrated Book")
                                .captionLarge()
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .background(categoryColor.opacity(0.08))
            .cornerRadius(AppSizing.cornerRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                    .stroke(categoryColor.opacity(0.3), lineWidth: 1)
            )
            .shadow(
                color: categoryColor.opacity(0.3),
                radius: 10,
                x: 0,
                y: 10
            )
        }
        .childSafeTouchTarget()
    }
}
