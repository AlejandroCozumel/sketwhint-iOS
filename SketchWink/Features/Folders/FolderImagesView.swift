import SwiftUI
import Combine

struct FolderImagesView: View {
    let folder: UserFolder
    @Binding var selectedTab: Int
    @Environment(\.dismiss) private var dismiss
    @StateObject private var folderService = FolderService.shared
    @StateObject private var profileService = ProfileService.shared
    
    @State private var images: [FolderImage] = []
    @State private var isLoading = true
    @State private var currentPage = 1
    @State private var hasMorePages = false
    @State private var totalImages = 0
    @State private var errorMessage: String?
    @State private var selectedImages: Set<String> = []
    @State private var isSelectionMode = false
    @State private var showingRemoveConfirmation = false
    @State private var selectedImageForDetail: FolderImage?
    
    // Filter States (same as gallery)
    @State private var showFavoritesOnly = false
    @State private var selectedCategory: String? = nil
    @State private var searchText = ""
    @State private var selectedProfileFilter: String? = nil
    
    // Auto-search with debouncing
    @State private var searchWorkItem: DispatchWorkItem?
    private let searchDebounceDelay: TimeInterval = 0.5 // 500ms debounce
    private let minimumSearchLength = 3
    
    // Categories from backend (same as gallery)
    @State private var availableCategories: [CategoryWithOptions] = []
    @State private var isLoadingCategories = false
    
    private let pageLimit = 20
    
    // Profile filtering logic (same as gallery)
    private var isMainProfile: Bool {
        profileService.currentProfile?.isDefault == true
    }
    
    private var filteredProfileOptions: [FamilyProfile] {
        profileService.availableProfiles.filter { !$0.isDefault }
    }
    
    // Filter state helpers
    private var hasActiveFilters: Bool {
        showFavoritesOnly || selectedCategory != nil || (!searchText.isEmpty && searchText.count >= minimumSearchLength) || selectedProfileFilter != nil
    }
    
    // MARK: - Computed Properties for Empty States
    private var emptyStateTitle: String {
        if showFavoritesOnly {
            return "No Favorite Images"
        } else if selectedCategory != nil {
            return "No \(selectedCategory!) Images"
        } else if selectedProfileFilter != nil {
            return "No Images from This Profile"
        } else if !searchText.isEmpty && searchText.count >= minimumSearchLength {
            return "No Results Found"
        } else if totalImages == 0 && !isLoading {
            return "Empty Folder"
        } else {
            return "No Images"
        }
    }
    
    private var emptyStateMessage: String {
        if showFavoritesOnly {
            return "No favorite images in this folder. Tap the heart icon on any image to add it to your favorites."
        } else if selectedCategory != nil {
            return "This folder doesn't have any \(selectedCategory!.lowercased()) images."
        } else if selectedProfileFilter != nil {
            return "This family member hasn't contributed any images to this folder yet."
        } else if !searchText.isEmpty && searchText.count >= minimumSearchLength {
            return "Try different search terms or clear filters to see more results."
        } else if totalImages == 0 && !isLoading {
            return "Move images from your gallery to organize them in this folder"
        } else {
            return "No images match your current filters."
        }
    }
    
    private var emptyStateButtonTitle: String {
        if hasActiveFilters {
            return "Clear Filters"
        } else {
            return "Go to Gallery"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Folder info header
                folderInfoHeader
                
                // Filter chips section (same as gallery)
                filterChipsSection
                    .padding(.top, AppSpacing.md)
                
                // Search bar section (same as gallery)
                searchBarSection
                
                // Search result summary (only show when actually searching with 3+ chars)
                if !searchText.isEmpty && searchText.count >= minimumSearchLength && !isLoading && !images.isEmpty {
                    SearchResultSummary(
                        searchTerm: searchText,
                        totalResults: images.count,
                        totalImages: totalImages,
                        onClearSearch: {
                            searchText = ""
                            applyFilters()
                        }
                    )
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.md)
                }
                
                // Minimum search length message
                if !searchText.isEmpty && searchText.count < minimumSearchLength && !isLoading {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(AppColors.infoBlue)
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("Type at least \(minimumSearchLength) characters to search")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Spacer()
                        
                        Button("Clear") {
                            searchText = ""
                            applyFilters()
                        }
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.primaryBlue)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.infoBlue.opacity(0.1))
                            .stroke(AppColors.infoBlue.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.bottom, AppSpacing.md)
                }
                
                // Content - WITH refreshable only on the scrollable content
                if isLoading && images.isEmpty {
                    loadingView
                } else if images.isEmpty {
                    emptyStateView
                } else {
                    imageGridView
                        .refreshable {
                            await refreshImages()
                        }
                }
            }
            .background(AppColors.backgroundLight)
            .navigationTitle(folder.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.primaryBlue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !images.isEmpty {
                        Menu {
                            Button(action: toggleSelectionMode) {
                                Label(
                                    isSelectionMode ? "Cancel Selection" : "Select Images",
                                    systemImage: isSelectionMode ? "xmark" : "checkmark.circle"
                                )
                            }
                            
                            if isSelectionMode && !selectedImages.isEmpty {
                                Button(role: .destructive, action: { showingRemoveConfirmation = true }) {
                                    Label("Remove from Folder", systemImage: "folder.badge.minus")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(AppTypography.titleMedium)
                                .foregroundColor(AppColors.primaryBlue)
                        }
                    }
                }
            }
            .task {
                await loadCategories()
                await loadImages()
            }
            .alert("Remove Images", isPresented: $showingRemoveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    Task { await removeSelectedImages() }
                }
            } message: {
                Text("Remove \(selectedImages.count) image\(selectedImages.count == 1 ? "" : "s") from this folder? The images will return to your main gallery.")
            }
            .sheet(item: $selectedImageForDetail) { folderImage in
                NavigationView {
                    if let imageIndex = images.firstIndex(where: { $0.id == folderImage.id }) {
                        FolderImageDetailView(
                            folderImage: $images[imageIndex],
                            searchTerm: searchText,
                            onImageDeleted: { deletedImageId in
                                removeImageFromLocalState(deletedImageId)
                            }
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Folder Info Header
    private var folderInfoHeader: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.md) {
                // Folder icon with color
                ZStack {
                    Circle()
                        .fill(Color(hex: folder.color).opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Text(folder.icon)
                        .font(.system(size: 28))
                }
                
                // Folder details
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(folder.name)
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    
                    Text("\(totalImages) image\(totalImages == 1 ? "" : "s")")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                    
                    if let description = folder.description, !description.isEmpty {
                        Text(description)
                            .font(AppTypography.captionLarge)
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            
            // Selection info (if in selection mode)
            if isSelectionMode {
                HStack {
                    Text("\(selectedImages.count) selected")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.primaryBlue)
                    
                    Spacer()
                    
                    Button(selectedImages.count == images.count ? "Deselect All" : "Select All") {
                        if selectedImages.count == images.count {
                            selectedImages.removeAll()
                        } else {
                            selectedImages = Set(images.map { $0.id })
                        }
                    }
                    .font(AppTypography.captionLarge)
                    .foregroundColor(AppColors.primaryBlue)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.sm)
            }
            
            Divider()
                .background(AppColors.borderLight)
        }
    }
    
    // Define the same 2-column grid layout as the main gallery
    private let columns = [
        GridItem(.flexible(minimum: 100, maximum: .infinity), spacing: AppSpacing.grid.itemSpacing),
        GridItem(.flexible(minimum: 100, maximum: .infinity), spacing: AppSpacing.grid.itemSpacing)
    ]
    
    // MARK: - Image Grid View
    private var imageGridView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: AppSpacing.grid.rowSpacing) {
                ForEach(images, id: \.id) { image in
                    FolderImageCard(
                        image: image,
                        isSelected: selectedImages.contains(image.id),
                        isSelectionMode: isSelectionMode,
                        searchTerm: searchText,
                        onTap: {
                            if isSelectionMode {
                                toggleImageSelection(image.id)
                            } else {
                                selectedImageForDetail = image
                            }
                        },
                        onLongPress: {
                            if !isSelectionMode {
                                isSelectionMode = true
                                selectedImages.insert(image.id)
                            }
                        },
                        onFavorite: {
                            Task {
                                await toggleImageFavorite(image)
                            }
                        }
                    )
                }
                
                // Load more indicator
                if hasMorePages {
                    loadMoreView
                        .onAppear {
                            Task { await loadMoreImages() }
                        }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.xl)
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: AppSpacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(AppColors.primaryBlue)
            
            Text("Loading images...")
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: AppSpacing.lg) {
            ZStack {
                Circle()
                    .fill(Color(hex: folder.color).opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Text(folder.icon)
                    .font(.system(size: 60))
            }
            
            VStack(spacing: AppSpacing.sm) {
                Text(emptyStateTitle)
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(emptyStateMessage)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
            
            Button(action: {
                if hasActiveFilters {
                    clearAllFilters()
                } else {
                    // Navigate to Gallery tab (tag 1) and dismiss folder sheet
                    selectedTab = 1
                    dismiss()
                }
            }) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text(emptyStateButtonTitle)
                        .font(AppTypography.titleMedium)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.md)
                .background(AppColors.primaryBlue)
                .clipShape(Capsule())
            }
            .childSafeTouchTarget()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, AppSpacing.xl)
    }
    
    // MARK: - Load More View
    private var loadMoreView: some View {
        VStack(spacing: AppSpacing.sm) {
            ProgressView()
                .scaleEffect(0.8)
                .tint(AppColors.primaryBlue)
            
            Text("Loading more...")
                .font(AppTypography.captionLarge)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
    }
    
    // MARK: - Methods
    private func loadImages() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await loadImagesPage(page: 1)
            
            await MainActor.run {
                self.images = response.images
                self.totalImages = response.total
                self.currentPage = response.page
                self.hasMorePages = response.images.count >= pageLimit && response.total > response.images.count
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func refreshImages() async {
        // Don't set isLoading to avoid showing loading overlay during pull-to-refresh
        currentPage = 1

        do {
            let response = try await loadImagesPage(page: 1)

            await MainActor.run {
                self.images = response.images
                self.totalImages = response.total
                self.currentPage = response.page
                self.hasMorePages = response.images.count >= pageLimit && response.total > response.images.count
            }

        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func loadMoreImages() async {
        guard hasMorePages && !isLoading else { return }
        
        do {
            let nextPage = currentPage + 1
            let response = try await loadImagesPage(page: nextPage)
            
            await MainActor.run {
                self.images.append(contentsOf: response.images)
                self.currentPage = nextPage
                self.hasMorePages = response.images.count >= pageLimit && response.total > self.images.count
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func loadImagesPage(page: Int) async throws -> FolderImagesResponse {
        let favorites = showFavoritesOnly ? true : nil
        // Only search if text is empty OR has at least minimum characters
        let search: String?
        if searchText.isEmpty {
            search = nil
        } else if searchText.count >= minimumSearchLength {
            search = searchText
            #if DEBUG
            print("🔍 FolderImagesView: Using search term '\(searchText)' (\(searchText.count) chars)")
            #endif
        } else {
            search = nil
            #if DEBUG
            print("🔍 FolderImagesView: Ignoring search term '\(searchText)' - below minimum \(minimumSearchLength) characters")
            #endif
        }
        
        return try await folderService.getFolderImages(
            folderId: folder.id,
            page: page,
            limit: pageLimit,
            favorites: favorites,
            category: selectedCategory,
            search: search,
            filterByProfile: selectedProfileFilter
        )
    }
    
    private func toggleSelectionMode() {
        isSelectionMode.toggle()
        if !isSelectionMode {
            selectedImages.removeAll()
        }
    }
    
    private func toggleImageSelection(_ imageId: String) {
        if selectedImages.contains(imageId) {
            selectedImages.remove(imageId)
        } else {
            selectedImages.insert(imageId)
        }
    }
    
    private func removeSelectedImages() async {
        guard !selectedImages.isEmpty else { return }
        
        do {
            _ = try await folderService.removeImagesFromFolder(
                folderId: folder.id,
                imageIds: Array(selectedImages)
            )
            
            await MainActor.run {
                // Remove images from local array
                self.images.removeAll { selectedImages.contains($0.id) }
                self.totalImages -= selectedImages.count
                self.selectedImages.removeAll()
                self.isSelectionMode = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Local State Management for Image Updates
    private func removeImageFromLocalState(_ imageId: String) {
        // Remove the deleted image from local state immediately
        images.removeAll { $0.id == imageId }
        
        // Also update the total count
        if totalImages > 0 {
            totalImages -= 1
        }
        
        #if DEBUG
        print("🗑️ FolderImagesView: Removed image from local state")
        print("   - Image ID: \(imageId)")
        print("   - Remaining images: \(images.count)")
        print("   - Total count: \(totalImages)")
        #endif
    }
    
    // MARK: - Filter Chips Section (same as gallery)
    private var filterChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                // All/Favorites Toggle (always show)
                FilterChip(
                    title: "All",
                    icon: "square.grid.2x2",
                    isSelected: !showFavoritesOnly
                ) {
                    showFavoritesOnly = false
                    applyFilters()
                }
                
                FilterChip(
                    title: "Favorites",
                    icon: "heart.fill",
                    isSelected: showFavoritesOnly
                ) {
                    showFavoritesOnly = true
                    applyFilters()
                }
                
                // Profile filters (only for admin users with multiple profiles)
                if isMainProfile && profileService.availableProfiles.count > 1 {
                    // Separator
                    Rectangle()
                        .fill(AppColors.borderLight)
                        .frame(width: 1, height: 24)
                        .padding(.horizontal, AppSpacing.xs)
                    
                    // All Profiles chip
                    FilterChip(
                        title: "All Profiles",
                        icon: "person.2.fill",
                        isSelected: selectedProfileFilter == nil
                    ) {
                        selectedProfileFilter = nil
                        applyFilters()
                    }
                    
                    // Individual profile chips
                    ForEach(filteredProfileOptions) { profile in
                        FilterChip(
                            title: profile.name,
                            icon: "person.circle.fill",
                            isSelected: selectedProfileFilter == profile.id
                        ) {
                            selectedProfileFilter = profile.id
                            applyFilters()
                        }
                    }
                }
                
                // Category filters (always show if available)
                if !availableCategories.isEmpty {
                    // Separator
                    Rectangle()
                        .fill(AppColors.borderLight)
                        .frame(width: 1, height: 24)
                        .padding(.horizontal, AppSpacing.xs)
                    
                    // Category chips
                    ForEach(availableCategories, id: \.id) { categoryWithOptions in
                        let category = categoryWithOptions.category
                        ModernCategoryChip(
                            category: category,
                            isSelected: selectedCategory == category.id,
                            action: {
                                selectedCategory = selectedCategory == category.id ? nil : category.id
                                applyFilters()
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
        .padding(.bottom, AppSpacing.sm)
        .id("folder-images-filter-chips-\(availableCategories.count)-\(profileService.availableProfiles.count)")
    }
    
    // MARK: - Search Bar Section (same as gallery)
    private var searchBarSection: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textSecondary)
                .font(.system(size: 16, weight: .medium))
            
            TextField("Search in this folder...", text: $searchText)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimary)
                .onChange(of: searchText) {
                    print("🔍 DEBUG: FolderImagesView SearchText changed to: '\(searchText)'")
                    handleSearchTextChange()
                }
            
            if !searchText.isEmpty {
                Button {
                    // Cancel any pending search
                    searchWorkItem?.cancel()
                    searchText = ""
                    // Clear search immediately - no debounce
                    applyFilters()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textSecondary)
                        .font(.system(size: 16))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.surfaceLight.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.2), value: searchText.isEmpty)
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
    }
    
    // MARK: - Filter Application Methods
    private func applyFilters() {
        #if DEBUG
        print("🔍 FolderImagesView: Applying filters")
        print("   - Favorites only: \(showFavoritesOnly)")
        print("   - Category: \(selectedCategory ?? "All")")
        print("   - Profile filter: \(selectedProfileFilter ?? "All")")
        print("   - Search: \(searchText.isEmpty ? "None" : searchText)")
        #endif
        
        Task {
            await loadImages()
        }
    }
    
    // MARK: - Auto-Search with Debouncing
    private func handleSearchTextChange() {
        // Cancel previous search work item
        searchWorkItem?.cancel()
        
        // Clear search immediately if text is empty
        if searchText.isEmpty {
            #if DEBUG
            print("🔍 FolderImagesView: Search cleared - immediate refresh")
            #endif
            applyFilters()
            return
        }
        
        // Don't search if less than minimum characters
        if searchText.count < minimumSearchLength {
            #if DEBUG
            print("🔍 FolderImagesView: Search text '\(searchText)' below minimum \(minimumSearchLength) characters")
            #endif
            return
        }
        
        // Create new debounced search work item
        let workItem = DispatchWorkItem {
            #if DEBUG
            print("🔍 FolderImagesView: Debounced search triggered for '\(self.searchText)'")
            #endif
            self.applyFilters()
        }
        
        searchWorkItem = workItem
        
        // Execute after debounce delay
        DispatchQueue.main.asyncAfter(deadline: .now() + searchDebounceDelay, execute: workItem)
        
        #if DEBUG
        print("🔍 FolderImagesView: Search debounce timer started for '\(searchText)' (\(searchDebounceDelay)s)")
        #endif
    }
    
    private func clearAllFilters() {
        showFavoritesOnly = false
        selectedCategory = nil
        searchText = ""
        selectedProfileFilter = nil
        
        // Reload images without filters
        Task {
            await loadImages()
        }
    }
    
    // MARK: - Favorite Management
    private func toggleImageFavorite(_ folderImage: FolderImage) async {
        do {
            // Call API to toggle favorite
            try await GenerationService.shared.toggleImageFavorite(imageId: folderImage.id)
            
            // Update local state
            await MainActor.run {
                if let index = images.firstIndex(where: { $0.id == folderImage.id }) {
                    images[index].isFavorite.toggle()
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Categories Loading (same as gallery)
    private func loadCategories() async {
        isLoadingCategories = true
        
        do {
            let generationService = GenerationService.shared
            let categories = try await generationService.getCategoriesWithOptions()
            
            await MainActor.run {
                availableCategories = categories
                isLoadingCategories = false
            }
        } catch {
            await MainActor.run {
                // Categories loading is not critical for the folder functionality
                // We can fail silently and use fallback UI
                isLoadingCategories = false
                #if DEBUG
                print("❌ Failed to load categories for filters: \(error)")
                #endif
            }
        }
    }
}

// MARK: - Folder Image Card
struct FolderImageCard: View {
    let image: FolderImage
    let isSelected: Bool
    let isSelectionMode: Bool
    let searchTerm: String
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onFavorite: () -> Void
    
    @State private var isPressed = false
    
    // Backend handles search filtering, no client-side matching needed
    
    var body: some View {
        Button(action: onTap) {
            GeometryReader { geometry in
                OptimizedAsyncImage(
                    url: URL(string: image.imageUrl),
                    thumbnailSize: 320,
                    quality: 0.8,
                    content: { optimizedImage in
                        optimizedImage
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: 160)
                            .clipped()
                            .cornerRadius(AppSizing.cornerRadius.md)
                    },
                    placeholder: {
                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                            .fill(AppColors.textSecondary.opacity(0.1))
                            .frame(width: geometry.size.width, height: 160)
                            .overlay(
                                ProgressView()
                                    .tint(AppColors.primaryBlue)
                            )
                    }
                )
                .overlay(
                    // Selection overlay
                    Group {
                        if isSelectionMode {
                            VStack {
                                HStack {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundColor(isSelected ? AppColors.successGreen : .white)
                                        .background(
                                            Circle()
                                                .fill(isSelected ? .white : Color.black.opacity(0.3))
                                                .frame(width: 28, height: 28)
                                        )
                                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                                    
                                    Spacer()
                                }
                                
                                Spacer()
                            }
                            .padding(AppSpacing.xs)
                        }
                    }
                )
                .overlay(
                    // Favorite button overlay (top-right)
                    Group {
                        if !isSelectionMode {
                            VStack {
                                HStack {
                                    Spacer()
                                    
                                    AnimatedFavoriteButton(
                                        isFavorite: image.isFavorite,
                                        onToggle: onFavorite
                                    )
                                }
                                .padding(.trailing, AppSpacing.sm)
                                .padding(.top, AppSpacing.sm)
                                
                                Spacer()
                            }
                        }
                    }
                )
                .overlay(
                    // Selection dim overlay
                    Group {
                        if isSelectionMode && !isSelected {
                            Color.black.opacity(0.2)
                                .cornerRadius(AppSizing.cornerRadius.md)
                        }
                    }
                )
                .overlay(
                    SearchIndicatorOverlay(
                        searchTerm: searchTerm
                    )
                )
                // Backend handles search filtering, no need for border highlighting
            }
        }
        .frame(height: 160) // Set fixed height for GeometryReader
        .frame(maxWidth: .infinity) // Ensure button respects grid cell width
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.5) {
            onLongPress()
        } onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }
    }
}

// MARK: - Folder Image Detail View
struct FolderImageDetailView: View {
    @Binding var folderImage: FolderImage
    @StateObject private var generationService = GenerationService.shared
    @StateObject private var profileService = ProfileService.shared
    @State private var isTogglingFavorite = false
    @State private var isDeleting = false
    @State private var error: Error?
    @State private var showingError = false
    @State private var showingDownloadView = false
    @State private var showingDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss

    let searchTerm: String
    let onImageDeleted: ((String) -> Void)?

    init(folderImage: Binding<FolderImage>, searchTerm: String = "", onImageDeleted: ((String) -> Void)? = nil) {
        self._folderImage = folderImage
        self.searchTerm = searchTerm
        self.onImageDeleted = onImageDeleted
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                
                // Full size image with favorite button overlay
                AsyncImage(url: URL(string: folderImage.imageUrl)) { imagePhase in
                    switch imagePhase {
                    case .success(let swiftUIImage):
                        swiftUIImage
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(AppSizing.cornerRadius.lg)
                            .overlay(
                                // Favorite button - TOP RIGHT
                                AnimatedFavoriteButton(
                                    isFavorite: folderImage.isFavorite,
                                    onToggle: {
                                        Task {
                                            await toggleFavorite()
                                        }
                                    }
                                )
                                .disabled(isTogglingFavorite)
                                .opacity(isTogglingFavorite ? 0.6 : 1.0)
                                .padding(AppSpacing.md),
                                alignment: .topTrailing
                            )
                    case .failure(_), .empty:
                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                            .fill(AppColors.textSecondary.opacity(0.1))
                            .frame(height: 300)
                            .overlay(
                                ProgressView()
                                    .tint(AppColors.primaryBlue)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
                
                // Image info
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Details")
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    VStack(spacing: AppSpacing.sm) {
                        DetailRowHighlighted(label: "Title", value: folderImage.generation.title, searchTerm: searchTerm)
                        DetailRowHighlighted(label: "Category", value: folderImage.generation.category, searchTerm: searchTerm)
                        DetailRowHighlighted(label: "Style", value: folderImage.generation.option, searchTerm: searchTerm)
                        DetailRow(label: "Model", value: folderImage.generation.modelUsed)
                        DetailRow(label: "Quality", value: folderImage.generation.qualityUsed.capitalized)
                        
                        // Show creator info if available and different from current user
                        if let creatorProfileId = folderImage.createdBy.profileId,
                           let creatorName = folderImage.createdBy.profileName,
                           creatorProfileId != profileService.currentProfile?.id {
                            DetailRowHighlighted(label: "Created by", value: creatorName, searchTerm: searchTerm)
                        }

                        DetailRow(label: "Created", value: formatDate(folderImage.generation.createdAt ?? folderImage.movedAt))
                        DetailRow(label: "Moved to folder", value: formatDate(folderImage.movedAt))
                        
                        // Show notes if available
                        if let notes = folderImage.notes, !notes.isEmpty {
                            DetailRowHighlighted(label: "Notes", value: notes, searchTerm: searchTerm)
                        }
                    }
                }
                .cardStyle()
                
                // Action buttons row
                HStack(spacing: AppSpacing.md) {
                    // Download button (left side)
                    Button {
                        showingDownloadView = true
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Text("📥")
                            Text("Download")
                                .font(AppTypography.titleMedium)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .largeButtonStyle(backgroundColor: AppColors.primaryPurple)
                    .childSafeTouchTarget()
                    
                    // Delete button (right side)
                    Button {
                        showingDeleteConfirmation = true
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            if isDeleting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Text("🗑️")
                            }
                            Text(isDeleting ? "Deleting..." : "Delete")
                                .font(AppTypography.titleMedium)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .largeButtonStyle(backgroundColor: AppColors.errorRed)
                    .disabled(isDeleting)
                    .childSafeTouchTarget()
                }
            }
            .pageMargins()
            .padding(.vertical, AppSpacing.sectionSpacing)
        }
        .background(AppColors.backgroundLight)
        .navigationTitle("Image Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .font(AppTypography.titleMedium)
                .foregroundColor(AppColors.primaryBlue)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(error?.localizedDescription ?? "An error occurred")
        }
        .sheet(isPresented: $showingDownloadView) {
            // Convert FolderImage to GeneratedImage for download view
            if let generatedImage = convertToGeneratedImage(folderImage) {
                ImageDownloadView(image: generatedImage)
            }
        }
        .alert("Delete Image", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteImage()
                }
            }
        } message: {
            Text("Are you sure you want to delete this image? This action cannot be undone.")
        }
    }
    
    // MARK: - Helper Methods
    private func toggleFavorite() async {
        isTogglingFavorite = true

        do {
            // Call API to toggle favorite
            try await generationService.toggleImageFavorite(imageId: folderImage.id)

            // Update local state (binding will sync automatically)
            await MainActor.run {
                folderImage.isFavorite.toggle()
                isTogglingFavorite = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                showingError = true
                isTogglingFavorite = false
            }
        }
    }
    
    private func deleteImage() async {
        isDeleting = true
        
        do {
            // Call API to delete image
            try await generationService.deleteImage(imageId: folderImage.id)
            
            // If successful, notify parent and dismiss
            await MainActor.run {
                isDeleting = false
                onImageDeleted?(folderImage.id)
                dismiss()
            }
        } catch {
            await MainActor.run {
                self.error = error
                showingError = true
                isDeleting = false
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        // Try ISO8601 formatter first
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = iso8601Formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            displayFormatter.timeZone = TimeZone.current
            displayFormatter.locale = Locale.current
            return displayFormatter.string(from: date)
        }

        // Fallback: try without fractional seconds
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            displayFormatter.timeZone = TimeZone.current
            displayFormatter.locale = Locale.current
            return displayFormatter.string(from: date)
        }

        // If all fails, return original string
        return dateString
    }
    
    private func convertToGeneratedImage(_ folderImage: FolderImage) -> GeneratedImage? {
        // Convert FolderImage to GeneratedImage for download functionality
        // This is a helper to reuse the existing ImageDownloadView
        return GeneratedImage(
            id: folderImage.id,
            imageUrl: folderImage.imageUrl,
            optionIndex: folderImage.optionIndex,
            isFavorite: folderImage.isFavorite,
            originalUserPrompt: nil, // Not available in FolderImage
            enhancedPrompt: nil,
            wasEnhanced: nil,
            wasFromImageUpload: nil,
            modelUsed: folderImage.generation.modelUsed,
            qualityUsed: folderImage.generation.qualityUsed,
            dimensionsUsed: nil,
            createdAt: folderImage.movedAt, // Use movedAt since that's what we have
            generation: GenerationInfo(
                id: folderImage.generation.id,
                title: folderImage.generation.title,
                category: folderImage.generation.category,
                option: folderImage.generation.option,
                modelUsed: folderImage.generation.modelUsed,
                qualityUsed: folderImage.generation.qualityUsed,
                createdAt: folderImage.generation.createdAt  // Already optional in API
            ),
            collections: nil,
            createdBy: CreatedByProfile(
                profileId: folderImage.createdBy.profileId,
                profileName: folderImage.createdBy.profileName ?? "Unknown",
                profileAvatar: nil // Not available in folder image
            )
        )
    }
}

#Preview {
    @Previewable @State var selectedTab = 3

    return FolderImagesView(
        folder: UserFolder(
            id: "1",
            name: "Family Photos",
            description: "Our favorite family moments",
            color: "#8B5CF6",
            icon: "📁",
            imageCount: 24,
            sortOrder: 0,
            createdAt: "2024-01-15T10:30:00Z",
            updatedAt: "2024-01-15T10:30:00Z",
            createdBy: CreatedBy(
                profileId: "profile_123",
                profileName: "Mom"
            )
        ),
        selectedTab: $selectedTab
    )
}