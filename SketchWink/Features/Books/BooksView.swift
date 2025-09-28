import SwiftUI

struct BooksView: View {
    @StateObject private var booksService = BooksService.shared
    @StateObject private var profileService = ProfileService.shared
    @StateObject private var folderService = FolderService.shared
    
    @State private var selectedBook: StoryBook?
    @State private var showingBookReader = false
    @State private var showingFilters = false
    @State private var showingMoveToFolder = false
    @State private var bookToMove: StoryBook?
    
    // Filter states
    @State private var showFavoritesOnly = false
    @State private var selectedProfileFilter: String?
    
    // Loading and error states
    @State private var isLoadingMore = false
    @State private var currentPage = 1
    @State private var hasMorePages = true
    
    private var isMainProfile: Bool {
        profileService.currentProfile?.isDefault == true
    }
    
    private var filteredProfileOptions: [FamilyProfile] {
        profileService.availableProfiles.filter { !$0.isDefault }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter chips (only for main profiles with multiple profiles)
            if isMainProfile && profileService.availableProfiles.count > 1 {
                filterChipsSection
            }
            
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                // All Profiles chip
                FilterChip(
                    title: "All Profiles",
                    icon: "person.2.fill",
                    isSelected: selectedProfileFilter == nil
                ) {
                    Task {
                        selectedProfileFilter = nil
                        currentPage = 1
                        hasMorePages = true
                        await loadBooks(page: 1, replace: true)
                    }
                }
                
                // Individual profile chips
                ForEach(filteredProfileOptions) { profile in
                    FilterChip(
                        title: profile.name,
                        icon: "person.circle.fill",
                        isSelected: selectedProfileFilter == profile.id
                    ) {
                        Task {
                            selectedProfileFilter = profile.id
                            currentPage = 1
                            hasMorePages = true
                            await loadBooks(page: 1, replace: true)
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
        .padding(.bottom, AppSpacing.sm)
    }
    
    // MARK: - Books Grid Section
    private var booksGridSection: some View {
        Group {
            if booksService.isLoading && booksService.books.isEmpty {
                loadingView
            } else if booksService.books.isEmpty {
                emptyStateView
            } else {
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
            Text("📚")
                .font(.system(size: 64))
            
            Text("No Story Books Yet")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
            
            Text("Create your first story book from the Art tab!")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
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
    
    @MainActor
    private func refreshBooks() async {
        currentPage = 1
        hasMorePages = true
        await loadBooks(page: 1, replace: true)
    }
    
    @MainActor
    private func loadBooks(page: Int, replace: Bool = false) async {
        do {
            let response = try await booksService.getBooks(
                page: page,
                favorites: showFavoritesOnly ? true : nil,
                filterByProfile: selectedProfileFilter
            )
            
            if replace {
                booksService.books = response.books
            } else {
                booksService.books.append(contentsOf: response.books)
            }
            
            hasMorePages = response.books.count == response.limit
            booksService.error = nil
            
        } catch {
            booksService.error = error.localizedDescription
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
            try await booksService.toggleBookFavorite(bookId: book.id)
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
}