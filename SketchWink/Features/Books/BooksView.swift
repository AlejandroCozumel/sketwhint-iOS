import SwiftUI

struct BooksView: View {
    @StateObject private var booksService = BooksService.shared
    @StateObject private var profileService = ProfileService.shared
    @StateObject private var folderService = FolderService.shared
    @StateObject private var generationService = GenerationService.shared
    @StateObject private var tokenManager = TokenBalanceManager.shared
    @StateObject private var localization = LocalizationManager.shared

    @State private var selectedBook: StoryBook?
    @State private var showingBookReader = false
    @State private var showingFilters = false
    @State private var showingMoveToFolder = false
    @State private var bookToMove: StoryBook?
    @State private var showSubscriptionPlans = false
    @State private var showingProfileMenu = false
    @State private var showPainting = false
    @State private var showSettings = false
    @State private var showCreateBook = false
    @State private var createdDraft: StoryDraft?

    // Filter states
    @State private var showFavoritesOnly = false
    @State private var selectedProfileFilter: String?
    @State private var selectedCategory: String?
    
    // Categories from backend (story book options)
    @State private var availableCategories: [FilterCategory] = []
    
    // Loading and error states
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var currentPage = 1
    @State private var hasMorePages = true
    
    private var isMainProfile: Bool {
        profileService.currentProfile?.isDefault == true
    }
    
    private var filteredProfileOptions: [FamilyProfile] {
        // Show all profiles like folders does - don't filter out the admin profile
        profileService.availableProfiles
    }
    
    // MARK: - Computed Properties for Empty States
    private var hasActiveFilters: Bool {
        showFavoritesOnly || selectedProfileFilter != nil || selectedCategory != nil
    }
    
    private var emptyStateIcon: String {
        if showFavoritesOnly {
            return "💖"
        } else if selectedCategory != nil {
            return "📖"
        } else if selectedProfileFilter != nil {
            return "👤"
        } else {
            return "📚"
        }
    }

    private var emptyStateSFSymbol: String {
        if showFavoritesOnly {
            return "heart.slash"
        } else if selectedCategory != nil {
            return "book.closed"
        } else if selectedProfileFilter != nil {
            return "person.crop.circle.badge.questionmark"
        } else {
            return "book.closed"
        }
    }
    
    private var emptyStateTitle: String {
        if showFavoritesOnly {
            return "No Favorite Books"
        } else if let selectedCategory = selectedCategory {
            return "No \(selectedCategory) Books"
        } else if selectedProfileFilter != nil {
            return "No Books from This Profile"
        } else {
            return "No Story Books Yet"
        }
    }
    
    private var emptyStateMessage: String {
        if showFavoritesOnly {
            return "Tap the heart icon on any book to add it to your favorites."
        } else if let selectedCategory = selectedCategory {
            return "No \(selectedCategory.lowercased()) have been created yet. Try creating some from the Art tab or select a different category."
        } else if selectedProfileFilter != nil {
            return "This family member hasn't created any story books yet."
        } else {
            return "Create your first story book from the Art tab!"
        }
    }
    
    private var emptyStateButtonTitle: String? {
        if hasActiveFilters {
            return "Clear Filters"
        } else {
            return "Create Story Book"
        }
    }

    private func emptyStateButtonAction() {
        if hasActiveFilters {
            clearAllFilters()
        } else {
            showCreateBook = true
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
    
    var body: some View {
        VStack(spacing: 0) {
            if UIDevice.current.userInterfaceIdiom == .pad {
                iPadTabHeader(
                    profileService: profileService,
                    tokenManager: tokenManager,
                    title: "books.title".localized,
                    onMenuTap: { showingProfileMenu = true },
                    onCreditsTap: { /* TODO: Show purchase credits modal */ },
                    onUpgradeTap: { showSubscriptionPlans = true }
                ) {
                    Button {
                        showCreateBook = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(AppColors.primaryPink)
                            .frame(width: 36, height: 36)
                    }
                    .childSafeTouchTarget()
                }
            }

            // Filter chips (always show for favorites, conditionally show profile filters)
            filterChipsSection

            // Books grid
            booksGridSection
        }
        .iPadContentPadding() // Apply to entire view including title
        .background(AppColors.backgroundLight)
        .navigationTitle(UIDevice.current.userInterfaceIdiom == .pad ? "nav.books".localized : "books.title".localized)
        .navigationBarTitleDisplayMode(UIDevice.current.userInterfaceIdiom == .pad ? .inline : .large)
        .toolbar {
            if UIDevice.current.userInterfaceIdiom != .pad {
                SimpleToolbarContent(
                    profileService: profileService,
                    onMenuTap: { showingProfileMenu = true }
                )

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateBook = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(AppColors.primaryPink)
                            .frame(width: 36, height: 36)
                    }
                }
            }
        }
        .onAppear {
            loadInitialBooks()
            loadCategories()
        }
        .onChange(of: localization.currentLanguage) { oldValue, newValue in
            #if DEBUG
            print("📚 BooksView: Language changed from \(oldValue) to \(newValue), reloading categories")
            #endif
            loadCategories()
        }
        .dismissableFullScreenCover(item: $selectedBook) { book in
            BookReadingView(book: book)
        }
        .dismissableFullScreenCover(isPresented: $showingFilters) {
            filtersSheet
        }
        .dismissableFullScreenCover(isPresented: $showingMoveToFolder) {
            if let book = bookToMove {
                MoveToFolderSheet(
                    book: book,
                    folders: folderService.folders,
                    onMove: { folderId, notes in
                        Task {
                            await moveBookToFolder(book: book, folderId: folderId, notes: notes)
                        }
                    }
                )
            }
        }
        .dismissableFullScreenCover(isPresented: $showSubscriptionPlans) {
            SubscriptionPlansView()
        }
        .dismissableFullScreenCover(isPresented: $showingProfileMenu) {
            ProfileMenuSheet(
                selectedTab: .constant(2),
                showPainting: $showPainting,
                showSettings: $showSettings
            )
        }
        .dismissableFullScreenCover(isPresented: $showSettings) {
            SettingsView()
        }
        .dismissableFullScreenCover(isPresented: $showPainting) {
            NavigationView {
                PaintingView()
            }
        }
        .dismissableFullScreenCover(isPresented: $showCreateBook) {
            StoryDraftCreationView(
                productCategory: storyBooksCategory,
                onDismiss: {
                    showCreateBook = false
                },
                onDraftCreated: { draft in
                    createdDraft = draft
                    showCreateBook = false
                    // Refresh books list after creation
                    loadInitialBooks()
                }
            )
        }
    }
    
    // MARK: - Filter Chips Section
    private var filterChipsSection: some View {
        UnifiedFilterChips(
            config: FilterConfig(
                profileService: profileService,
                showFavoritesOnly: showFavoritesOnly,
                selectedProfileFilter: selectedProfileFilter,
                selectedCategory: selectedCategory,
                isSearchActive: false,
                availableProfiles: filteredProfileOptions, // Use all profiles (consistent with folders)
                availableCategories: availableCategories,
                showFavoritesToggle: true,
                showProfileFilters: true,
                showCategoryFilters: !availableCategories.isEmpty,
                showSearchToggle: false,
                onFavoritesToggle: { isFavorites in
                    showFavoritesOnly = isFavorites
                    applyFilters()
                },
                onProfileFilterChange: { profileId in
                    selectedProfileFilter = profileId
                    applyFilters()
                },
                onCategoryFilterChange: { categoryId in
                    selectedCategory = categoryId
                    applyFilters()
                },
                onSearchToggle: { },
                chipSelectedColor: AppColors.primaryPink
            )
        )
        .id("books-filter-chips-\(availableCategories.count)-\(profileService.availableProfiles.count)")
    }
    
    // MARK: - Books Grid Section
    private var booksGridSection: some View {
        Group {
            if isLoading && booksService.books.isEmpty {
                #if DEBUG
                let _ = print("📚 BooksView: Showing loading view - isLoading: \(isLoading), books count: \(booksService.books.count)")
                #endif
                loadingView
            } else if booksService.books.isEmpty {
                #if DEBUG
                let _ = print("📚 BooksView: Showing empty state - isLoading: \(isLoading), books count: \(booksService.books.count), error: \(booksService.error ?? "none")")
                #endif
                emptyStateView
            } else {
                #if DEBUG
                let _ = print("📚 BooksView: Showing books grid - isLoading: \(isLoading), books count: \(booksService.books.count)")
                #endif
                booksGrid
            }
        }
    }
    
    private var booksGrid: some View {
        ScrollView {
            LazyVGrid(columns: GridLayouts.categoryGrid, spacing: AppSpacing.grid.itemSpacing) {
                ForEach(booksService.books) { book in
                    BookCard(
                        book: book,
                        showCreatorName: isMainProfile && profileService.availableProfiles.count > 1,
                        onTap: {
                            selectedBook = book
                            showingBookReader = true
                        },
                        onFavorite: {
                            Task {
                                await toggleBookFavorite(book)
                            }
                        },
                        onMoveToFolder: {
                            bookToMove = book
                            showingMoveToFolder = true
                        }
                    )
                }
                
                // Load more indicator
                if hasMorePages && !booksService.books.isEmpty {
                    loadMoreView
                        .onAppear {
                            Task {
                                await loadMoreBooks()
                            }
                        }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.xl)
        }
        .refreshable {
            await refreshBooks()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppColors.primaryPink)

            Text("Loading story books...")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: AppSpacing.lg) {
            // SF Symbol icon (matching Folders pattern)
            Image(systemName: emptyStateSFSymbol)
                .font(.system(size: 60))
                .foregroundColor(AppColors.primaryPink.opacity(0.6))

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

            if let buttonTitle = emptyStateButtonTitle {
                Button(action: {
                    emptyStateButtonAction()
                }) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: hasActiveFilters ? "xmark.circle" : "book.fill")
                            .font(.system(size: 16, weight: .semibold))

                        Text(buttonTitle)
                            .font(AppTypography.titleMedium)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.primaryPink)
                    .clipShape(Capsule())
                }
                .childSafeTouchTarget()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, AppSpacing.xl)
    }
    
    private var loadMoreView: some View {
        VStack {
            if isLoadingMore {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(AppColors.primaryPink)
            }
        }
        .frame(height: 50)
    }
    
    // MARK: - Filters Sheet
    private var filtersSheet: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Favorites toggle
                Toggle("Favorites Only", isOn: $showFavoritesOnly)
                    .font(AppTypography.bodyMedium)
                    .toggleStyle(SwitchToggleStyle(tint: AppColors.primaryPink))

                Spacer()
            }
            .padding(AppSpacing.md)
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        showFavoritesOnly = false
                        selectedProfileFilter = nil
                    }
                    .foregroundColor(AppColors.primaryPink)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        showingFilters = false
                        currentPage = 1
                        hasMorePages = true
                        Task {
                            await loadBooks(page: 1, replace: true)
                        }
                    }
                    .foregroundColor(AppColors.primaryPink)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Data Loading Methods
    private func loadInitialBooks() {
        Task {
            await loadBooks(page: 1, replace: true)
        }
    }
    
    private func loadCategories() {
        Task {
            do {
                // Load book themes (translated based on user's preferred language)
                let themesResponse = try await booksService.getThemes()

                await MainActor.run {
                    // Map themes to FilterCategory format
                    // Store theme responses for later use when filtering
                    self.booksService.themes = themesResponse.themes

                    // IMPORTANT: Use theme.id as the filter ID (contains the option ID like "sb1-bedtime-stories")
                    // Display the translated name to the user, but we'll map back to the English name when filtering
                    availableCategories = themesResponse.themes.map { theme in
                        FilterCategory(
                            id: theme.id,           // Use option ID (e.g., "sb1-bedtime-stories")
                            name: theme.name,       // Display translated name (e.g., "Cuentos para Dormir")
                            icon: "📚",
                            color: AppColors.primaryPink  // Always use pink for book categories
                        )
                    }
                }

                #if DEBUG
                print("📚 BooksView: Loaded \(themesResponse.themes.count) book themes")
                themesResponse.themes.forEach { theme in
                    print("   - \(theme.name) (id: \(theme.id))")
                }
                #endif
            } catch {
                #if DEBUG
                print("❌ BooksView: Error loading book themes - \(error)")
                #endif
            }
        }
    }
    
    @MainActor
    private func refreshBooks() async {
        currentPage = 1
        hasMorePages = true
        await loadBooks(page: 1, replace: true)
    }
    
    @MainActor
    private func loadBooks(page: Int, replace: Bool = false) async {
        // Set loading state for initial loads
        if replace {
            isLoading = true
            currentPage = 1
            hasMorePages = true
        }
        
        do {
            let response = try await booksService.getBooks(
                page: page,
                favorites: showFavoritesOnly ? true : nil,
                filterByProfile: selectedProfileFilter,
                category: selectedCategory
            )
            
            if replace {
                booksService.books = response.books
            } else {
                booksService.books.append(contentsOf: response.books)
            }
            
            hasMorePages = response.books.count == response.limit
            booksService.error = nil
            isLoading = false
            
            #if DEBUG
            print("✅ BooksView: Loaded \(response.books.count) books (total: \(response.total), page: \(page))")
            #endif
            
        } catch {
            booksService.error = error.localizedDescription
            isLoading = false
            #if DEBUG
            print("❌ BooksView: Error loading books - \(error)")
            #endif
        }
    }
    
    @MainActor
    private func loadMoreBooks() async {
        guard !isLoadingMore && hasMorePages else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        await loadBooks(page: currentPage, replace: false)
        isLoadingMore = false
    }
    
    @MainActor
    private func toggleBookFavorite(_ book: StoryBook) async {
        do {
            // Store original state for animation logic
            let wasOriginallyFavorite = book.isFavorite
            
            // Call API to toggle favorite (BooksService handles local state update)
            try await booksService.toggleBookFavorite(bookId: book.id)
            
            // If we're viewing favorites only and the book was unfavorited, animate removal
            if showFavoritesOnly && wasOriginallyFavorite {
                // Find the book in the current list and remove with animation
                if let currentIndex = booksService.books.firstIndex(where: { $0.id == book.id && !$0.isFavorite }) {
                    _ = withAnimation(.easeOut(duration: 0.3)) {
                        booksService.books.remove(at: currentIndex)
                    }
                }
            }
        } catch {
            booksService.error = error.localizedDescription
        }
    }
    
    @MainActor
    private func moveBookToFolder(book: StoryBook, folderId: String, notes: String?) async {
        do {
            let _ = try await booksService.moveBookToFolder(
                bookId: book.id,
                folderId: folderId,
                notes: notes
            )
            
            // Refresh the books list after moving
            await refreshBooks()
            
        } catch {
            booksService.error = error.localizedDescription
        }
        
        showingMoveToFolder = false
        bookToMove = nil
    }
    
    // MARK: - Filter Helper Methods
    
    private func applyFilters() {
        #if DEBUG
        print("📚 BooksView: Applying filters")
        print("   - Favorites only: \(showFavoritesOnly)")
        print("   - Profile filter: \(selectedProfileFilter ?? "All")")
        #endif
        
        Task {
            await loadBooks(page: 1, replace: true)
        }
    }
    
    private func clearAllFilters() {
        showFavoritesOnly = false
        selectedProfileFilter = nil
        selectedCategory = nil
        
        // Reload books without filters
        Task {
            await loadBooks(page: 1, replace: true)
        }
    }
}
