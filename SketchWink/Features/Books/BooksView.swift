import SwiftUI

struct BooksView: View {
    @StateObject private var booksService = BooksService.shared
    @StateObject private var profileService = ProfileService.shared
    @StateObject private var folderService = FolderService.shared
    @StateObject private var generationService = GenerationService.shared
    
    @State private var selectedBook: StoryBook?
    @State private var showingBookReader = false
    @State private var showingFilters = false
    @State private var showingMoveToFolder = false
    @State private var bookToMove: StoryBook?
    
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
            // Navigate to Art tab to create story books
            // This would require access to the parent TabView selection
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter chips (always show for favorites, conditionally show profile filters)
            filterChipsSection
            
            // Books grid
            booksGridSection
        }
        .navigationTitle("📚 Story Books")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            // Only show toolbar filter button when profile chips are not shown
            if !(isMainProfile && profileService.availableProfiles.count > 1) {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Filters") {
                        showingFilters = true
                    }
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.primaryBlue)
                }
            }
        }
        .onAppear {
            loadInitialBooks()
            loadCategories()
        }
        .refreshable {
            await refreshBooks()
        }
        .sheet(item: $selectedBook) { book in
            BookReadingView(book: book)
        }
        .sheet(isPresented: $showingFilters) {
            filtersSheet
        }
        .sheet(isPresented: $showingMoveToFolder) {
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
                onSearchToggle: { }
            )
        )
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
    }
    
    private var loadingView: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppColors.primaryBlue)
            
            Text("Loading story books...")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: AppSpacing.lg) {
            Text(emptyStateIcon)
                .font(.system(size: 64))
            
            Text(emptyStateTitle)
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            
            Text(emptyStateMessage)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            
            if emptyStateButtonTitle != nil {
                Button(emptyStateButtonTitle!) {
                    emptyStateButtonAction()
                }
                .largeButtonStyle(backgroundColor: AppColors.primaryBlue)
                .childSafeTouchTarget()
                .padding(.top, AppSpacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, AppSpacing.xl)
        .padding(.bottom, AppSpacing.xl)
    }
    
    private var loadMoreView: some View {
        VStack {
            if isLoadingMore {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(AppColors.primaryBlue)
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
                    .toggleStyle(SwitchToggleStyle(tint: AppColors.primaryBlue))
                
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
                    .foregroundColor(AppColors.primaryBlue)
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
                    .foregroundColor(AppColors.primaryBlue)
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
                let categories = try await generationService.getCategoriesWithOptions()
                
                // Find story_books category and extract its options
                if let storyBooksCategory = categories.first(where: { $0.category.id == "story_books" }) {
                    await MainActor.run {
                        availableCategories = storyBooksCategory.options.map { option in
                            FilterCategory(
                                id: option.name,
                                name: option.name,
                                icon: "📚",
                                color: AppColors.primaryBlue
                            )
                        }
                    }
                    
                    #if DEBUG
                    print("📚 BooksView: Loaded \\(availableCategories.count) story book categories")
                    for category in availableCategories {
                        print("   - \\(category.name)")
                    }
                    #endif
                }
            } catch {
                #if DEBUG
                print("❌ BooksView: Error loading categories - \\(error)")
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
                    withAnimation(.easeOut(duration: 0.3)) {
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