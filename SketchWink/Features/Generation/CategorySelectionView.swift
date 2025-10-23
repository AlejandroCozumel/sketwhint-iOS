import SwiftUI

struct CategorySelectionView: View {
    @StateObject private var generationService = GenerationService.shared
    @StateObject private var productService = ProductCategoriesService.shared
    @StateObject private var draftService = DraftService.shared
    @StateObject private var profileService = ProfileService.shared
    @StateObject private var tokenManager = TokenBalanceManager.shared
    @StateObject private var localization = LocalizationManager.shared
    @ObservedObject private var bedtimeStoriesService = BedtimeStoriesService.shared
    @Binding var selectedTab: Int
    @State private var categories: [CategoryWithOptions] = []
    @State private var productCategories: [ProductCategory] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var showingError = false
    @State private var selectedCategory: CategoryWithOptions?
    @State private var selectedProductCategory: ProductCategory?
    @State private var createdDraft: StoryDraft?
    @State private var activeProductCategoryForGeneration: ProductCategory?
    @State private var navigateToCreationMethod = false
    @State private var navigateToBookGeneration = false
    @State private var showingProfileMenu = false
    @State private var showPainting = false
    @State private var showSettings = false
    @State private var showSubscriptionPlans = false
    @State private var showBedtimeStories = false
    
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sectionSpacing) {
                if isLoading {
                    loadingView
                } else {
                    // Categories Grid
                    categoriesGridView

                    // Bedtime Stories Section
                    bedtimeStoriesSection

                    // Books Section (Commented Out - Not Ready)
                    // booksSection
                }
            }
            .pageMargins()
            .padding(.vertical, AppSpacing.sectionSpacing)
        }
        .background(AppColors.backgroundLight)
        .navigationTitle("generation.title".localized)
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            AppToolbarContent(
                profileService: profileService,
                tokenManager: tokenManager,
                onProfileTap: { showingProfileMenu = true },
                onCreditsTap: { /* TODO: Show purchase credits modal */ },
                onUpgradeTap: { showSubscriptionPlans = true }
            )
        }
        .sheet(isPresented: $showingProfileMenu) {
            ProfileMenuSheet(
                selectedTab: $selectedTab,
                showPainting: $showPainting,
                showSettings: $showSettings
            )
        }
        .sheet(isPresented: $showSubscriptionPlans) {
            SubscriptionPlansView()
        }
        .fullScreenCover(isPresented: $showPainting) {
            NavigationView {
                PaintingView()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showBedtimeStories) {
            NavigationView {
                BedtimeStoriesCreateView(category: bedtimeStoriesService.category)
            }
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
        .sheet(item: $selectedCategory) { category in
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
        // Navigation-based flow instead of stacked sheets
        .background(
            Group {
                NavigationLink(
                    destination:
                        Group {
                            if let productCategory = selectedProductCategory {
                                SimpleCreationMethodView(
                                    productCategory: productCategory,
                                    onDismiss: {
                                        navigateToCreationMethod = false
                                        selectedProductCategory = nil
                                    },
                                    onDraftCreated: { draft in
                                        // Navigate to story review/preview before generating book
                                        activeProductCategoryForGeneration = productCategory
                                        createdDraft = draft
                                        navigateToBookGeneration = true
                                    }
                                )
                            } else {
                                EmptyView()
                            }
                        },
                    isActive: $navigateToCreationMethod
                ) { EmptyView() }
                NavigationLink(
                    destination:
                        Group {
                            if let draft = createdDraft {
                                StoryDraftDetailView(
                                    draft: draft,
                                    onDismiss: {
                                        navigateToBookGeneration = false
                                        selectedProductCategory = nil
                                        createdDraft = nil
                                        activeProductCategoryForGeneration = nil
                                    }
                                )
                            } else {
                                EmptyView()
                            }
                        },
                    isActive: $navigateToBookGeneration
                ) { EmptyView() }
            }
        )
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: AppSpacing.sectionSpacing) {

            // Categories skeleton
            skeletonCategoriesView

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

    // MARK: - Skeleton Books
    private var skeletonBooksView: some View {
        VStack(alignment: .center, spacing: AppSpacing.md) {
            // Section title skeleton
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.textSecondary.opacity(0.3))
                .frame(width: 120, height: 24)
                .shimmer()
                .padding(.bottom, 10)

            // Book card skeleton
            SkeletonBookCard()
        }
    }
    
    // MARK: - Categories Grid
    private var categoriesGridView: some View {
        VStack(alignment: .center, spacing: AppSpacing.md) {
            Text(String(localized: "generation.creative.categories"))
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

    // MARK: - Books Section (Commented Out)
    /*
    private var booksSection: some View {
        VStack(alignment: .center, spacing: AppSpacing.md) {
            Text("Story Books")
                .font(AppTypography.categoryTitle)
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 10)

            if productCategories.isEmpty {
                // Loading state or empty state for books
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.textSecondary)

                    Text("Story books coming soon!")
                        .bodyMedium()
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .background(AppColors.surfaceLight)
                .cornerRadius(AppSizing.cornerRadius.md)
            } else {
                VStack(spacing: AppSpacing.md) {
                    ForEach(productCategories) { productCategory in
                        ProductCategoryCard(productCategory: productCategory) {
                            #if DEBUG
                            print("📚 CategorySelection: Selected book category \(productCategory.name)")
                            print("   - Draft endpoint: \(productCategory.draftEndpoint)")
                            print("   - Generate endpoint: \(productCategory.generateEndpoint)")
                            #endif
                            // TODO: Navigate to story draft creation
                            handleBookCategorySelection(productCategory)
                        }
                    }
                }
            }
        }
    }
    */

    // MARK: - Methods
    private func generateBookWithDefaults(for draft: StoryDraft) async {
        #if DEBUG
        print("📖 CategorySelectionView: Generating book with default settings for draft: \(draft.title)")
        #endif

        // Use default values for book generation
        let request = GenerateBookFromDraftRequest(
            model: "seedream",           // Default model
            quality: "standard",        // Default quality
            dimensions: "a4"           // Default dimensions
        )

        do {
            let response = try await draftService.generateBookFromDraft(draftId: draft.id, options: request)

            #if DEBUG
            print("📖 CategorySelectionView: Book generation started with ID: \(response.productId)")
            #endif

            await MainActor.run {
                // Reset navigation state and show success
                navigateToCreationMethod = false
                selectedProductCategory = nil
                createdDraft = nil
                activeProductCategoryForGeneration = nil

                // Could show a success message or navigate to book status
                #if DEBUG
                print("📖 CategorySelectionView: Book generation initiated successfully")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ CategorySelectionView: Book generation failed: \(error)")
            #endif

            await MainActor.run {
                self.error = error
                showingError = true
            }
        }
    }

    // MARK: - Methods

    private func loadCategories() async {
        isLoading = true
        
        do {
            // Load regular categories (backend now excludes books automatically)
            categories = try await generationService.getCategoriesWithOptions()
            
            // Load product categories (books)
            let productResponse = try await productService.getProductCategories()
            productCategories = productResponse.products
            
            // Load bedtime stories themes and category info
            _ = try await bedtimeStoriesService.getThemes()
            
            #if DEBUG
            print("🎨 CategorySelection: Loaded \(categories.count) visual art categories")
            print("📚 CategorySelection: Loaded \(productCategories.count) product categories")
            print("🌙 CategorySelection: Loaded \(bedtimeStoriesService.themes.count) bedtime story themes")
            #endif
            
        } catch {
            self.error = error
            showingError = true
        }
        
        isLoading = false
    }
    
    private func handleBookCategorySelection(_ productCategory: ProductCategory) {
        print("📚 CategorySelection: Book category selected - \(productCategory.name)")
        print("   - Product type: \(productCategory.productType)")
        print("   - Draft endpoint: \(productCategory.draftEndpoint)")
        print("   - Generate endpoint: \(productCategory.generateEndpoint)")
        
        // Push to creation method page instead of presenting as a sheet
        selectedProductCategory = productCategory
        navigateToCreationMethod = true
        print("📚 CategorySelection: navigating to creation method for: \(productCategory.name)")
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
                                .frame(maxWidth: .infinity)
                                .frame(height: 100, alignment: .top)
                                .clipped()
                        case .failure(_):
                            Rectangle()
                                .fill(categoryColor.opacity(0.2))
                                .frame(maxWidth: .infinity)
                                .frame(height: 100)
                                .overlay(
                                    Text(category.icon ?? "🎨")
                                        .font(.system(size: 40))
                                )
                        case .empty:
                            // Skeleton loading state
                            Rectangle()
                                .fill(AppColors.textSecondary.opacity(0.3))
                                .frame(maxWidth: .infinity)
                                .frame(height: 100)
                                .shimmer()
                        @unknown default:
                            Rectangle()
                                .fill(categoryColor.opacity(0.2))
                                .frame(maxWidth: .infinity)
                                .frame(height: 100)
                                .overlay(
                                    Text(category.icon ?? "🎨")
                                        .font(.system(size: 40))
                                )
                        }
                    }
                } else {
                    Rectangle()
                        .fill(categoryColor.opacity(0.2))
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
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
            .frame(height: 200)
            .frame(maxWidth: .infinity)
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

// MARK: - Product Category Card
struct ProductCategoryCard: View {
    let productCategory: ProductCategory
    let action: () -> Void
    
    private var categoryColor: Color {
        if !productCategory.color.isEmpty {
            return Color(hex: productCategory.color)
        }
        
        // Books get a specific color - warm brown/amber for storytelling
        switch productCategory.productType {
        case "book": return Color(hex: "#D97706") // Amber-600
        default: return AppColors.primaryBlue
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                // Left: Product Icon
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Text(productCategory.icon)
                            .font(.system(size: 32))
                    )
                    .overlay(
                        Circle()
                            .stroke(categoryColor.opacity(0.3), lineWidth: 2)
                    )
                
                // Center: Main Content
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        Text(productCategory.name)
                            .titleMedium()
                            .foregroundColor(AppColors.textPrimary)
                        
                        Spacer()
                        
                        // Product type badge
                        Text(productCategory.productType.capitalized)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(categoryColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(categoryColor.opacity(0.15))
                            .cornerRadius(8)
                    }
                    
                    Text(productCategory.description)
                        .bodyMedium()
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Additional info row - full width
                    HStack {
                        // Token cost
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(AppColors.warningOrange)
                                .font(.system(size: 12))
                            Text("\(productCategory.tokenCost) tokens")
                                .captionLarge()
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Estimated duration
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(AppColors.infoBlue)
                                .font(.system(size: 12))
                            Text(productCategory.estimatedDuration)
                                .captionLarge()
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                    .fill(categoryColor.opacity(0.05))
                    .shadow(
                        color: categoryColor.opacity(0.1),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                            .stroke(categoryColor.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .childSafeTouchTarget()
    }
}

// MARK: - Simple Creation Method View
struct SimpleCreationMethodView: View {
    @State private var selectedMethod: CreationMethod?
    @State private var showingAIAssisted = false
    @State private var showingManualCreation = false
    
    let productCategory: ProductCategory
    let onDismiss: () -> Void
    let onDraftCreated: (StoryDraft) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    // Header
                    headerView
                    
                    // Method Selection Cards
                    methodSelectionView
                    
                    // Continue Button
                    continueButtonView
                }
                .pageMargins()
                .padding(.vertical, AppSpacing.sectionSpacing)
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("Create Story")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showingAIAssisted) {
            AIAssistedCreationView(
                productCategory: productCategory,
                onDismiss: {
                    showingAIAssisted = false
                },
                onDraftCreated: { draft in
                    showingAIAssisted = false
                    onDraftCreated(draft)
                }
            )
        }
        .sheet(isPresented: $showingManualCreation) {
            StoryDraftCreationView(
                productCategory: productCategory,
                onDismiss: {
                    showingManualCreation = false
                },
                onDraftCreated: { draft in
                    showingManualCreation = false
                    onDraftCreated(draft)
                }
            )
        }
    }
    
    // MARK: - Header View
    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: AppSpacing.md) {
            Text(productCategory.icon)
                .font(.system(size: AppSizing.iconSizes.xxl))
            
            VStack(spacing: AppSpacing.xs) {
                Text("How would you like to create?")
                    .headlineLarge()
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Choose your preferred way to create your story book")
                    .bodyMedium()
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                
                // Token cost and duration info
                HStack(spacing: AppSpacing.md) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(AppColors.warningOrange)
                            .font(.system(size: 12))
                        Text("\(productCategory.tokenCost) tokens")
                            .captionLarge()
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(AppColors.infoBlue)
                            .font(.system(size: 12))
                        Text(productCategory.estimatedDuration)
                            .captionLarge()
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .padding(AppSpacing.cardPadding.inner)
        .background(productColor.opacity(0.1))
        .cornerRadius(AppSizing.cornerRadius.md)
        .shadow(
            color: Color.black.opacity(AppSizing.shadows.small.opacity),
            radius: AppSizing.shadows.small.radius,
            x: AppSizing.shadows.small.x,
            y: AppSizing.shadows.small.y
        )
    }
    
    // MARK: - Method Selection
    @ViewBuilder
    private var methodSelectionView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Choose Creation Method")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
            
            VStack(spacing: AppSpacing.md) {
                ForEach(CreationMethod.allCases, id: \.rawValue) { method in
                    CreationMethodCard(
                        method: method,
                        isSelected: selectedMethod == method,
                        productColor: productColor
                    ) {
                        selectedMethod = method
                    }
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Continue Button
    private var continueButtonView: some View {
        VStack(spacing: AppSpacing.sm) {
            Button("Continue") {
                guard let method = selectedMethod else { return }
                
                switch method {
                case .aiAssisted:
                    showingAIAssisted = true
                case .manual:
                    showingManualCreation = true
                }
            }
            .largeButtonStyle(backgroundColor: selectedMethod != nil ? productColor : AppColors.buttonDisabled)
            .disabled(selectedMethod == nil)
            .opacity(selectedMethod != nil ? 1.0 : 0.6)
            .childSafeTouchTarget()
            
            if selectedMethod == nil {
                Text("Please select a creation method")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Computed Properties
    private var productColor: Color {
        if !productCategory.color.isEmpty {
            return Color(hex: productCategory.color)
        }
        
        switch productCategory.productType {
        case "book": return Color(hex: "#D97706") // Amber-600
        default: return AppColors.primaryBlue
        }
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
                .frame(height: 100)
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
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                .fill(AppColors.textSecondary.opacity(0.1))
        )
        .clipShape(RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg))
    }
}

// MARK: - Skeleton Book Card
struct SkeletonBookCard: View {
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Left: Icon skeleton
            Circle()
                .fill(AppColors.textSecondary.opacity(0.3))
                .frame(width: 64, height: 64)
                .shimmer()

            // Center: Content skeleton
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColors.textSecondary.opacity(0.3))
                        .frame(width: 100, height: 16)
                        .shimmer()

                    Spacer()

                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColors.textSecondary.opacity(0.2))
                        .frame(width: 50, height: 14)
                        .shimmer()
                }

                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColors.textSecondary.opacity(0.2))
                    .frame(height: 14)
                    .shimmer()

                HStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColors.textSecondary.opacity(0.2))
                        .frame(width: 80, height: 12)
                        .shimmer()

                    Spacer()

                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColors.textSecondary.opacity(0.2))
                        .frame(width: 60, height: 12)
                        .shimmer()
                }
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                .fill(AppColors.textSecondary.opacity(0.1))
        )
    }
}
