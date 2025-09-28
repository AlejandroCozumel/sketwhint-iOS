import SwiftUI
import Photos

struct GalleryView: View {
    @StateObject private var generationService = GenerationService.shared
    @StateObject private var profileService = ProfileService.shared
    @State private var images: [GeneratedImage] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var showingError = false
    @State private var selectedImage: GeneratedImage?
    @State private var currentPage = 1
    @State private var hasMorePages = true
    @State private var totalImages = 0
    @State private var lastLoadTime = Date()
    
    // Filter States
    @State private var showFavoritesOnly = false
    @State private var selectedCategory: String? = nil
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var selectedProfileFilter: String? = nil  // NEW: Profile filter
    
    // Selection Mode States
    @State private var selectedImages: Set<String> = []
    @State private var isSelectionMode = false
    @State private var showingFolderPicker = false
    
    // Categories from backend
    @State private var availableCategories: [CategoryWithOptions] = []
    @State private var isLoadingCategories = false
    
    private let columns = [
        GridItem(.flexible(minimum: 100, maximum: .infinity), spacing: AppSpacing.grid.itemSpacing),
        GridItem(.flexible(minimum: 100, maximum: .infinity), spacing: AppSpacing.grid.itemSpacing)
    ]
    
    // MARK: - Computed Properties for Empty States
    private var hasActiveFilters: Bool {
        showFavoritesOnly || selectedCategory != nil || !searchText.isEmpty || selectedProfileFilter != nil
    }
    
    private var emptyStateIcon: String {
        if showFavoritesOnly {
            return "💖"
        } else if selectedCategory != nil {
            return "🎨"
        } else if selectedProfileFilter != nil {
            return "👤"
        } else if !searchText.isEmpty {
            return "🔍"
        } else {
            return "🎨"
        }
    }
    
    private var emptyStateTitle: String {
        if showFavoritesOnly {
            return "No Favorite Images"
        } else if selectedCategory != nil {
            return "No \(selectedCategory!) Images"
        } else if selectedProfileFilter != nil {
            return "No Images from This Profile"
        } else if !searchText.isEmpty {
            return "No Results Found"
        } else {
            return "No Creations Yet"
        }
    }
    
    private var emptyStateMessage: String {
        if showFavoritesOnly {
            return "Tap the heart icon on any image to add it to your favorites."
        } else if selectedCategory != nil {
            return "Create some \(selectedCategory!.lowercased()) to see them here."
        } else if selectedProfileFilter != nil {
            return "This family member hasn't created any images yet."
        } else if !searchText.isEmpty {
            return "Try different search terms or clear filters to see more results."
        } else {
            return "Start creating amazing coloring pages, stickers, and more! Your generated art will appear here."
        }
    }
    
    private var emptyStateButtonTitle: String {
        if hasActiveFilters {
            return "Clear Filters"
        } else {
            return "Create Your First Art"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area
            ScrollView {
                LazyVStack(spacing: AppSpacing.sectionSpacing) {
                    
                    if isLoading && images.isEmpty {
                        loadingView
                    } else if images.isEmpty {
                        emptyStateView
                    } else {
                        galleryGridView
                    }
                }
                .pageMargins()
                .padding(.vertical, AppSpacing.sectionSpacing)
                .padding(.bottom, isSelectionMode && !selectedImages.isEmpty ? 80 : 0) // Add bottom padding when toolbar is visible
            }
            
            // Sticky bottom toolbar for selection actions
            if isSelectionMode && !selectedImages.isEmpty {
                selectionModeBottomToolbar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: isSelectionMode)
            }
        }
        .background(AppColors.backgroundLight)
        .navigationTitle("My Gallery")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !images.isEmpty {
                    Button(action: toggleSelectionMode) {
                        Text(isSelectionMode ? "Cancel" : "Select")
                            .font(AppTypography.titleMedium)
                            .foregroundColor(AppColors.primaryBlue)
                    }
                    .childSafeTouchTarget()
                }
            }
        }
        .task {
            await loadCategories()
            await loadImages()
        }
        .onAppear {
            #if DEBUG
            print("🔍 GalleryView: Profile filter visibility check")
            print("   - Available profiles count: \(profileService.availableProfiles.count)")
            print("   - Current profile: \(profileService.currentProfile?.name ?? "nil")")
            print("   - Is default profile: \(profileService.currentProfile?.isDefault ?? false)")
            print("   - Profile filters visible: \(profileService.availableProfiles.count > 1 && profileService.currentProfile?.isDefault == true)")
            print("   - Creator names will be shown: \(profileService.currentProfile?.isDefault == true)")
            print("   - Current profile ID: \(profileService.currentProfile?.id ?? "nil")")
            #endif
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(error?.localizedDescription ?? "An unknown error occurred")
        }
        .sheet(item: $selectedImage) { image in
            NavigationView {
                ImageDetailView(
                    image: image,
                    onImageDeleted: { deletedImageId in
                        removeImageFromLocalState(deletedImageId)
                    }
                )
            }
        }
        .sheet(isPresented: $showingFolderPicker) {
            FolderPickerView(
                selectedImages: Array(selectedImages),
                onFolderSelected: { folder in
                    Task {
                        await moveSelectedImagesToFolder(folder)
                    }
                }
            )
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: AppSpacing.xl) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppColors.primaryBlue)
            
            Text("Loading your creations...")
                .font(AppTypography.bodyLarge)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 200)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: AppSpacing.xl) {
            Text(emptyStateIcon)
                .font(.system(size: 80))
            
            VStack(spacing: AppSpacing.md) {
                Text(emptyStateTitle)
                    .font(AppTypography.headlineLarge)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(emptyStateMessage)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                
                Button(emptyStateButtonTitle) {
                    // Clear filters if any are active
                    if hasActiveFilters {
                        clearAllFilters()
                    }
                    // Note: For no creations, user can tap the Art tab
                }
                .largeButtonStyle(backgroundColor: AppColors.coloringPagesColor)
                .childSafeTouchTarget()
            }
        }
        .cardStyle()
        .frame(maxWidth: .infinity)
        .frame(minHeight: 300)
    }
    
    // MARK: - Gallery Grid
    private var galleryGridView: some View {
        VStack(spacing: AppSpacing.sectionSpacing) {
            
            // Header with stats
            galleryHeaderView
            
            // Selection Mode Info
            if isSelectionMode {
                selectionModeHeader
            }
            
            // Filters UI
            filtersView
            
            // Images grid with smooth skeleton overlay
            ZStack {
                // Current images (fade out smoothly during loading)
                LazyVGrid(columns: columns, spacing: AppSpacing.grid.rowSpacing) {
                    ForEach(images.indices, id: \.self) { index in
                        GalleryImageCard(
                            image: $images[index],
                            showCreatorName: profileService.currentProfile?.isDefault == true,
                            currentProfileId: profileService.currentProfile?.id,
                            isSelected: selectedImages.contains(images[index].id),
                            isSelectionMode: isSelectionMode,
                            action: {
                                if isSelectionMode {
                                    toggleImageSelection(images[index].id)
                                } else {
                                    selectedImage = images[index]
                                }
                            },
                            onFavoriteToggle: { imageToToggle in
                                await toggleImageFavorite(imageToToggle, at: index)
                            },
                            onLongPress: {
                                #if DEBUG
                                print("🔥 LONG PRESS TRIGGERED on image: \(images[index].id)")
                                print("🔥 Current selection mode: \(isSelectionMode)")
                                #endif
                                
                                if !isSelectionMode {
                                    isSelectionMode = true
                                    selectedImages.insert(images[index].id)
                                    
                                    #if DEBUG
                                    print("🔥 Entered selection mode, selected image: \(images[index].id)")
                                    print("🔥 Total selected images: \(selectedImages.count)")
                                    #endif
                                }
                            }
                        )
                        .id("image-\(images[index].id)")
                    }
                    
                    // Smart infinite scroll trigger
                    if hasMorePages && !isLoading {
                        infiniteScrollTrigger
                    }
                }
                .opacity(isLoading ? 0.3 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: isLoading)
                
                // Skeleton overlay (appears on top during loading)
                if isLoading {
                    LazyVGrid(columns: columns, spacing: AppSpacing.grid.rowSpacing) {
                        ForEach(0..<6, id: \.self) { index in
                            SkeletonImageCard()
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.4), value: isLoading)
                }
            }
        }
    }
    
    // MARK: - Selection Mode Views
    private var selectionModeHeader: some View {
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
        .cardStyle()
    }
    
    // MARK: - Sticky Bottom Toolbar
    private var selectionModeBottomToolbar: some View {
        VStack(spacing: 0) {
            // Selection info bar
            HStack {
                Text("\(selectedImages.count) image\(selectedImages.count == 1 ? "" : "s") selected")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(AppColors.textSecondary)
                
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
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.surfaceLight)
            
            // Action buttons
            HStack(spacing: AppSpacing.md) {
                // Move to Folder button (primary action)
                Button(action: { showingFolderPicker = true }) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "folder")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("Move to Folder")
                            .font(AppTypography.titleMedium)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.lg) // Slightly larger for single button
                    .background(AppColors.primaryPurple)
                    .clipShape(Capsule())
                }
                .childSafeTouchTarget()
            }
            .padding(AppSpacing.md)
            .background(AppColors.backgroundLight)
        }
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(AppColors.borderLight),
            alignment: .top
        )
    }
    
    // MARK: - Gallery Header
    private var galleryHeaderView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("Your Creations")
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: AppSpacing.xxxs) {
                    Text("\(images.count) of \(totalImages) images")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                    
                    if hasMorePages {
                        Text("More available")
                            .font(AppTypography.captionSmall)
                            .foregroundColor(AppColors.primaryBlue.opacity(0.7))
                    }
                }
            }
            
            // Categories filter could go here in the future
        }
        .cardStyle()
    }
    
    // MARK: - Modern Filters View
    private var filtersView: some View {
        VStack(spacing: AppSpacing.sm) {
            
            // Search Bar
            modernSearchBarView
            
            // Filter Chips Row
            modernFilterChipsView
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Modern Search Bar
    private var modernSearchBarView: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textSecondary)
                .font(.system(size: 16, weight: .medium))
            
            TextField("Search your creations...", text: $searchText)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimary)
                .onSubmit {
                    applyFilters()
                }
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
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
    }
    
    // MARK: - Modern Filter Chips
    private var modernFilterChipsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                // All/Favorites Toggle Chips
                FilterChip(
                    title: "All",
                    icon: "square.grid.2x2",
                    isSelected: !showFavoritesOnly,
                    action: {
                        showFavoritesOnly = false
                        applyFilters()
                    }
                )
                
                FilterChip(
                    title: "Favorites",
                    icon: "heart.fill",
                    isSelected: showFavoritesOnly,
                    action: {
                        showFavoritesOnly = true
                        applyFilters()
                    }
                )
                
                // Separator
                Rectangle()
                    .fill(AppColors.borderLight)
                    .frame(width: 1, height: 24)
                    .padding(.horizontal, AppSpacing.xs)
                
                // Profile Filters (only show if multiple profiles exist AND current user is default/main profile)
                if profileService.availableProfiles.count > 1 && 
                   profileService.currentProfile?.isDefault == true {
                    // Separator
                    Rectangle()
                        .fill(AppColors.borderLight)
                        .frame(width: 1, height: 24)
                        .padding(.horizontal, AppSpacing.xs)
                    
                    // "All Profiles" chip
                    ProfileFilterChip(
                        title: "All Profiles",
                        icon: "person.2.fill",
                        isSelected: selectedProfileFilter == nil,
                        action: {
                            selectedProfileFilter = nil
                            applyFilters()
                        }
                    )
                    
                    // Individual Profile Chips
                    ForEach(profileService.availableProfiles, id: \.id) { profile in
                        ProfileFilterChip(
                            title: profile.name,
                            icon: profile.avatar ?? "👤",
                            isSelected: selectedProfileFilter == profile.id,
                            action: {
                                selectedProfileFilter = selectedProfileFilter == profile.id ? nil : profile.id
                                applyFilters()
                            }
                        )
                    }
                    
                    // Separator
                    Rectangle()
                        .fill(AppColors.borderLight)
                        .frame(width: 1, height: 24)
                        .padding(.horizontal, AppSpacing.xs)
                }
                
                // Dynamic Category Chips
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
            .padding(.horizontal, AppSpacing.md)
        }
        .padding(.horizontal, -AppSpacing.md)
    }
    
    // MARK: - Favorites Toggle
    private var favoritesToggleView: some View {
        HStack(spacing: AppSpacing.sm) {
            Text("Show:")
                .font(AppTypography.titleSmall)
                .foregroundColor(AppColors.textSecondary)
            
            Button {
                showFavoritesOnly = false
                applyFilters()
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Text("📁")
                    Text("All Images")
                        .font(AppTypography.captionLarge)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(showFavoritesOnly ? AppColors.surfaceLight : AppColors.primaryBlue)
                .foregroundColor(showFavoritesOnly ? AppColors.textPrimary : AppColors.textOnDark)
                .cornerRadius(AppSizing.cornerRadius.md)
            }
            .childSafeTouchTarget()
            
            Button {
                showFavoritesOnly = true
                applyFilters()
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Text("❤️")
                    Text("Favorites")
                        .font(AppTypography.captionLarge)
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(showFavoritesOnly ? AppColors.primaryBlue : AppColors.surfaceLight)
                .foregroundColor(showFavoritesOnly ? AppColors.textOnDark : AppColors.textPrimary)
                .cornerRadius(AppSizing.cornerRadius.md)
            }
            .childSafeTouchTarget()
            
            Spacer()
        }
    }
    
    // MARK: - Category Filters
    private var categoryFiltersView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Categories:")
                .font(AppTypography.titleSmall)
                .foregroundColor(AppColors.textSecondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    // "All" category chip
                    categoryChip(name: "All", id: nil, color: nil, icon: "📂", imageUrl: nil)
                    
                    // Dynamic categories from backend
                    ForEach(availableCategories, id: \.id) { categoryWithOptions in
                        let category = categoryWithOptions.category
                        categoryChip(
                            name: category.name,
                            id: category.id,
                            color: GalleryView.parseColor(category.color),
                            icon: category.icon,
                            imageUrl: category.imageUrl
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
            }
        }
    }
    
    // MARK: - Category Chip
    private func categoryChip(name: String, id: String?, color: Color?, icon: String?, imageUrl: String?) -> some View {
        let chipColor = color ?? AppColors.primaryBlue
        let chipIcon = icon ?? "📂"
        
        return Button {
            selectedCategory = id
            applyFilters()
        } label: {
            HStack(spacing: AppSpacing.xs) {
                // Use category image if available, otherwise fall back to icon
                if let imageUrl = imageUrl, !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { imagePhase in
                        switch imagePhase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 24, height: 24)
                                .clipShape(Circle())
                        case .failure(_), .empty:
                            Text(chipIcon)
                                .font(.system(size: 16))
                        @unknown default:
                            Text(chipIcon)
                                .font(.system(size: 16))
                        }
                    }
                } else {
                    Text(chipIcon)
                        .font(.system(size: 16))
                }
                
                Text(name)
                    .font(AppTypography.captionLarge)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(selectedCategory == id ? chipColor : AppColors.surfaceLight)
            .foregroundColor(selectedCategory == id ? AppColors.textOnDark : AppColors.textPrimary)
            .cornerRadius(AppSizing.cornerRadius.md)
        }
        .childSafeTouchTarget()
    }
    
    // MARK: - Infinite Scroll Trigger
    private var infiniteScrollTrigger: some View {
        VStack(spacing: AppSpacing.md) {
            if isLoading {
                HStack(spacing: AppSpacing.sm) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(AppColors.primaryBlue)
                    
                    Text("Loading more creations...")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(AppSpacing.lg)
            } else {
                // Fallback manual load more button (rarely shown)
                Button("Load More Creations") {
                    Task {
                        await loadMoreImages()
                    }
                }
                .font(AppTypography.titleMedium)
                .foregroundColor(AppColors.primaryBlue)
                .padding(AppSpacing.md)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 80)
        .onAppear {
            // Auto-load when this view appears (infinite scroll with debouncing)
            let now = Date()
            if !isLoading && now.timeIntervalSince(lastLoadTime) > 1.0 {
                lastLoadTime = now
                Task {
                    await loadMoreImages()
                }
            }
        }
    }
    
    // MARK: - Selection Mode Methods
    private func toggleSelectionMode() {
        #if DEBUG
        print("🔥 TOOLBAR: Toggle Selection Mode button tapped!")
        print("🔥 Selection mode BEFORE toggle: \(isSelectionMode)")
        #endif
        
        isSelectionMode.toggle()
        
        #if DEBUG
        print("🔥 Selection mode AFTER toggle: \(isSelectionMode)")
        #endif
        
        if !isSelectionMode {
            selectedImages.removeAll()
            #if DEBUG
            print("🔥 Cleared all selected images, exiting selection mode")
            #endif
        }
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
    
    private func toggleImageSelection(_ imageId: String) {
        if selectedImages.contains(imageId) {
            selectedImages.remove(imageId)
        } else {
            selectedImages.insert(imageId)
        }
    }
    
    private func moveSelectedImagesToFolder(_ folder: UserFolder) async {
        guard !selectedImages.isEmpty else { return }
        
        do {
            // Import FolderService
            let folderService = FolderService.shared
            
            _ = try await folderService.moveImagesToFolder(
                folderId: folder.id,
                imageIds: Array(selectedImages)
            )
            
            await MainActor.run {
                // Remove moved images from gallery (they're now organized)
                images.removeAll { selectedImages.contains($0.id) }
                
                // Update total count
                totalImages -= selectedImages.count
                
                // Clear selection and exit selection mode
                selectedImages.removeAll()
                isSelectionMode = false
                
                #if DEBUG
                print("✅ GalleryView: Moved \(selectedImages.count) images to folder '\(folder.name)'")
                #endif
            }
            
        } catch {
            await MainActor.run {
                self.error = error
                showingError = true
            }
        }
    }
    
    // MARK: - Methods
    private func loadImages() async {
        isLoading = true
        
        do {
            // Reset pagination
            currentPage = 1
            
            // Load first page of images
            let response = try await loadImagesPage(page: currentPage)
            
            await MainActor.run {
                images = response.images
                totalImages = response.total
                // Calculate if there are more pages: (page * limit) < total
                hasMorePages = (response.page * response.limit) < response.total
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                showingError = true
                isLoading = false
            }
        }
    }
    
    private func loadMoreImages() async {
        guard hasMorePages && !isLoading else { return }
        
        isLoading = true
        currentPage += 1
        
        do {
            let response = try await loadImagesPage(page: currentPage)
            
            await MainActor.run {
                images.append(contentsOf: response.images)
                // Calculate if there are more pages: (page * limit) < total
                hasMorePages = (response.page * response.limit) < response.total
                isLoading = false
            }
        } catch {
            await MainActor.run {
                currentPage -= 1 // Revert page increment on error
                self.error = error
                showingError = true
                isLoading = false
            }
        }
    }
    
    private func loadImagesPage(page: Int) async throws -> ImagesResponse {
        let favorites = showFavoritesOnly ? true : nil
        let search = searchText.isEmpty ? nil : searchText
        
        return try await generationService.getUserImages(
            page: page, 
            limit: 15, 
            favorites: favorites,
            category: selectedCategory,
            search: search,
            filterByProfile: selectedProfileFilter
        )
    }
    
    // MARK: - Filter Application
    private func applyFilters() {
        #if DEBUG
        print("🔍 GalleryView: Applying filters")
        print("   - Favorites only: \(showFavoritesOnly)")
        print("   - Category: \(selectedCategory ?? "All")")
        print("   - Profile filter: \(selectedProfileFilter ?? "All")")
        print("   - Search: \(searchText.isEmpty ? "None" : searchText)")
        #endif
        
        Task {
            await loadImages()
        }
    }
    
    // MARK: - Categories Loading
    private func loadCategories() async {
        isLoadingCategories = true
        
        do {
            let categories = try await generationService.getCategoriesWithOptions()
            
            await MainActor.run {
                availableCategories = categories
                isLoadingCategories = false
            }
        } catch {
            await MainActor.run {
                // Categories loading is not critical for the gallery functionality
                // We can fail silently and use fallback UI
                isLoadingCategories = false
                #if DEBUG
                print("❌ Failed to load categories for filters: \(error)")
                #endif
            }
        }
    }
    
    // MARK: - Color Parsing Helper
    static func parseColor(_ colorString: String?) -> Color? {
        guard let colorString = colorString else { return nil }
        
        // Handle hex colors
        if colorString.hasPrefix("#") {
            let hex = String(colorString.dropFirst())
            if hex.count == 6 {
                let scanner = Scanner(string: hex)
                var hexNumber: UInt64 = 0
                
                if scanner.scanHexInt64(&hexNumber) {
                    let r = Double((hexNumber & 0xff0000) >> 16) / 255
                    let g = Double((hexNumber & 0x00ff00) >> 8) / 255
                    let b = Double(hexNumber & 0x0000ff) / 255
                    return Color(red: r, green: g, blue: b)
                }
            }
        }
        
        // Fallback to nil for invalid colors
        return nil
    }
    
    // MARK: - Favorite Management
    private func toggleImageFavorite(_ image: GeneratedImage, at index: Int) async {
        do {
            // Call API to toggle favorite
            try await generationService.toggleImageFavorite(imageId: image.id)
            
            // Update local state
            await MainActor.run {
                images[index].isFavorite.toggle()
            }
        } catch {
            await MainActor.run {
                self.error = error
                showingError = true
            }
        }
    }
    
    // MARK: - Local State Management
    private func removeImageFromLocalState(_ imageId: String) {
        // Remove the deleted image from local state immediately
        images.removeAll { $0.id == imageId }
        
        // Also update the total count
        if totalImages > 0 {
            totalImages -= 1
        }
        
        #if DEBUG
        print("🗑️ GalleryView: Removed image from local state")
        print("   - Image ID: \(imageId)")
        print("   - Remaining images: \(images.count)")
        print("   - Total count: \(totalImages)")
        #endif
    }
}

// MARK: - Supporting Views
struct GalleryImageCard: View {
    @Binding var image: GeneratedImage
    let showCreatorName: Bool
    let currentProfileId: String?
    let isSelected: Bool
    let isSelectionMode: Bool
    let action: () -> Void
    let onFavoriteToggle: (GeneratedImage) async -> Void
    let onLongPress: () -> Void
    
    // MARK: - Overlay Components
    private var creatorNameOverlay: some View {
        Group {
            if let createdBy = image.createdBy,
               showCreatorName,
               shouldShowCreatorBadge(for: createdBy) {
                HStack {
                    VStack {
                        Spacer()
                        HStack {
                            Text(createdBy.profileName)
                                .font(AppTypography.captionSmall)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    LinearGradient(
                                        colors: [AppColors.primaryPurple, AppColors.primaryBlue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                                )
                                .shadow(color: AppColors.primaryPurple.opacity(0.3), radius: 2, x: 0, y: 1)
                            
                            Spacer()
                        }
                    }
                }
                .padding(AppSpacing.xs)
            }
        }
    }
    
    private var favoriteButtonOverlay: some View {
        HStack {
            Spacer()
            VStack {
                AnimatedFavoriteButton(
                    isFavorite: image.isFavorite,
                    onToggle: {
                        Task {
                            await onFavoriteToggle(image)
                        }
                    }
                )
                .padding(AppSpacing.xs)
                Spacer()
            }
        }
    }
    
    private var selectionModeOverlay: some View {
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
    }
    
    private var selectionDimOverlay: some View {
        Group {
            if isSelectionMode && !isSelected {
                Color.black.opacity(0.2)
                    .cornerRadius(AppSizing.cornerRadius.md)
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            GeometryReader { geometry in
                AsyncImage(url: URL(string: image.imageUrl)) { imagePhase in
                    switch imagePhase {
                    case .success(let swiftUIImage):
                        swiftUIImage
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: 160)
                            .clipped()
                            .cornerRadius(AppSizing.cornerRadius.md)
                            .overlay(creatorNameOverlay)
                            .overlay(favoriteButtonOverlay)
                            .overlay(selectionModeOverlay)
                            .overlay(selectionDimOverlay)
                    case .failure(_):
                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                            .fill(AppColors.textSecondary.opacity(0.1))
                            .frame(width: geometry.size.width, height: 160)
                            .overlay(
                                VStack(spacing: AppSpacing.xs) {
                                    Text("📷")
                                        .font(.system(size: 30))
                                    Text("Failed to load")
                                        .font(AppTypography.captionMedium)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            )
                    case .empty:
                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                            .fill(AppColors.textSecondary.opacity(0.1))
                            .frame(width: geometry.size.width, height: 160)
                            .overlay(
                                ProgressView()
                                    .tint(AppColors.primaryBlue)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
        .frame(height: 160) // Set fixed height for GeometryReader
        .frame(maxWidth: .infinity) // Ensure button respects grid cell width
        .onLongPressGesture {
            #if DEBUG
            print("🔥 GalleryImageCard: Long press gesture detected!")
            #endif
            onLongPress()
        }
        .childSafeTouchTarget()
    }
    
    // MARK: - Helper Methods
    private func shouldShowCreatorBadge(for createdBy: CreatedByProfile) -> Bool {
        // Don't show badge for unknown/legacy profiles (null profileId)
        guard let creatorProfileId = createdBy.profileId else {
            return false
        }
        
        // Show badge if profile ID is different from current user
        return creatorProfileId != currentProfileId
    }
}

// MARK: - Image Detail View (Simple)
struct ImageDetailView: View {
    @State private var image: GeneratedImage
    @StateObject private var generationService = GenerationService.shared
    @State private var isTogglingFavorite = false
    @State private var isDeleting = false
    @State private var error: Error?
    @State private var showingError = false
    @State private var showingDownloadView = false
    @State private var showingDeleteConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    let onImageDeleted: ((String) -> Void)?  // Callback with deleted image ID
    
    init(image: GeneratedImage, onImageDeleted: ((String) -> Void)? = nil) {
        self._image = State(initialValue: image)
        self.onImageDeleted = onImageDeleted
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                
                // Full size image with favorite button overlay
                AsyncImage(url: URL(string: image.imageUrl)) { imagePhase in
                    switch imagePhase {
                    case .success(let swiftUIImage):
                        swiftUIImage
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(AppSizing.cornerRadius.lg)
                            .overlay(
                                // Favorite button - TOP RIGHT
                                AnimatedFavoriteButton(
                                    isFavorite: image.isFavorite,
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
                        DetailRow(label: "Title", value: image.generation?.title ?? image.originalUserPrompt ?? "Unknown")
                        DetailRow(label: "Category", value: image.generation?.category ?? "Unknown")
                        DetailRow(label: "Style", value: image.generation?.option ?? "Unknown")
                        
                        // Show creator info for main users (only if created by someone else)
                        if let createdBy = image.createdBy,
                           let creatorProfileId = createdBy.profileId,
                           creatorProfileId != ProfileService.shared.currentProfile?.id {
                            DetailRow(label: "Created by", value: createdBy.profileName)
                        }
                        
                        DetailRow(label: "Created", value: formatDate(image.createdAt))
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
            Text(error?.localizedDescription ?? "Failed to update favorite status")
        }
        .sheet(isPresented: $showingDownloadView) {
            ImageDownloadView(image: image)
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
    
    // MARK: - Favorite Management
    private func toggleFavorite() async {
        isTogglingFavorite = true
        
        do {
            // Call API to toggle favorite
            try await generationService.toggleImageFavorite(imageId: image.id)
            
            // Update local state
            await MainActor.run {
                image.isFavorite.toggle()
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
    
    // MARK: - Delete Image
    private func deleteImage() async {
        isDeleting = true
        
        do {
            // Call API to delete image
            try await generationService.deleteImage(imageId: image.id)
            
            // If successful, notify parent and dismiss
            await MainActor.run {
                isDeleting = false
                onImageDeleted?(image.id)  // Notify gallery to remove the image
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
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .font(AppTypography.titleSmall)
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Twitter-Style Heart Animation (Article Implementation)
struct AnimatedFavoriteButton: View {
    let isFavorite: Bool
    let onToggle: () -> Void
    
    @State private var isLiked = false
    @State private var sparkleOpacity: Double = 0
    @State private var sparkleScale: CGFloat = 0
    @State private var heartScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Twitter-style animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                heartScale = 0.8
            }
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.4).delay(0.1)) {
                heartScale = 1.2
                sparkleScale = 1.0
                sparkleOpacity = 1.0
            }
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2)) {
                heartScale = 1.0
            }
            
            // Sparkles fade out
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                sparkleOpacity = 0
                sparkleScale = 1.5
            }
            
            // Reset sparkles
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                sparkleScale = 0
            }
            
            // Toggle state and call action
            isLiked.toggle()
            onToggle()
        }) {
            ZStack {
                // Main background circle
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                    .shadow(
                        color: isFavorite ? Color.pink.opacity(0.3) : Color.black.opacity(0.1),
                        radius: isFavorite ? 6 : 2,
                        x: 0,
                        y: 2
                    )
                
                // Sparkle Effect - Small yellow circles radiating outward
                ForEach(0..<8, id: \.self) { index in
                    Sparkle(index: index)
                        .opacity(sparkleOpacity)
                        .scaleEffect(sparkleScale)
                }
                
                // Heart icon with Twitter-style animation
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(
                        isFavorite ?
                        LinearGradient(
                            colors: [.pink, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(heartScale)
            }
        }
        .childSafeTouchTarget()
        .onAppear {
            isLiked = isFavorite
        }
        .onChange(of: isFavorite) {
            isLiked = isFavorite
        }
    }
}

// MARK: - Sparkle Component
struct Sparkle: View {
    let index: Int
    
    var body: some View {
        Circle()
            .fill(Color.yellow)
            .frame(width: 4, height: 4)
            .offset(sparkleOffset)
    }
    
    private var sparkleOffset: CGSize {
        // Calculate random offset in different directions
        let angle = Double(index) * (360.0 / 8.0) * .pi / 180.0
        let distance: CGFloat = CGFloat.random(in: 25...35)
        let randomX = cos(angle) * distance + CGFloat.random(in: -8...8)
        let randomY = sin(angle) * distance + CGFloat.random(in: -8...8)
        return CGSize(width: randomX, height: randomY)
    }
}

// MARK: - Modern Filter Chip
struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(title)
                    .font(AppTypography.captionLarge)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                isSelected ? AppColors.primaryBlue : Color.clear,
                in: Capsule()
            )
            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.clear : AppColors.borderMedium,
                        lineWidth: 1
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .childSafeTouchTarget()
    }
}

// MARK: - Modern Category Chip
struct ModernCategoryChip: View {
    let category: GenerationCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                // Category image or icon
                if let imageUrl = category.imageUrl, !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { imagePhase in
                        switch imagePhase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 20, height: 20)
                                .clipShape(Circle())
                        case .failure(_), .empty:
                            Text(category.icon ?? "📂")
                                .font(.system(size: 14))
                        @unknown default:
                            Text(category.icon ?? "📂")
                                .font(.system(size: 14))
                        }
                    }
                } else {
                    Text(category.icon ?? "📂")
                        .font(.system(size: 14))
                }
                
                Text(category.name)
                    .font(AppTypography.captionLarge)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                isSelected ? 
                (GalleryView.parseColor(category.color) ?? AppColors.primaryBlue) : 
                Color.clear,
                in: Capsule()
            )
            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? 
                        Color.clear : 
                        (GalleryView.parseColor(category.color)?.opacity(0.3) ?? AppColors.borderMedium),
                        lineWidth: 1.5
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .shadow(
                color: isSelected ? 
                (GalleryView.parseColor(category.color)?.opacity(0.3) ?? AppColors.primaryBlue.opacity(0.3)) : 
                Color.clear,
                radius: isSelected ? 4 : 0,
                x: 0,
                y: 2
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .childSafeTouchTarget()
    }
}

// MARK: - Enhanced Skeleton Loading Card
struct SkeletonImageCard: View {
    @State private var isAnimating = false
    @State private var pulse = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
            .fill(
                LinearGradient(
                    colors: [
                        AppColors.surfaceLight.opacity(0.8),
                        AppColors.surfaceLight.opacity(0.4),
                        AppColors.surfaceLight.opacity(0.8)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 160)
            .overlay(
                // Enhanced shimmer effect
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                AppColors.primaryBlue.opacity(0.1),
                                Color.white.opacity(0.6),
                                AppColors.primaryBlue.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(x: isAnimating ? 2.0 : 0.1)
                    .offset(x: isAnimating ? 150 : -150)
                    .animation(
                        .linear(duration: 1.8)
                        .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                    .clipped()
            )
            .overlay(
                // Animated skeleton favorite button
                VStack {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(AppColors.surfaceLight.opacity(pulse ? 0.3 : 0.6))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(AppColors.primaryBlue.opacity(0.2), lineWidth: 1)
                            )
                            .animation(
                                .easeInOut(duration: 1.2)
                                .repeatForever(autoreverses: true),
                                value: pulse
                            )
                    }
                    Spacer()
                }
                .padding(AppSpacing.xs)
            )
            .shadow(
                color: AppColors.primaryBlue.opacity(0.1),
                radius: 4,
                x: 0,
                y: 2
            )
            .scaleEffect(pulse ? 0.98 : 1.0)
            .animation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true),
                value: pulse
            )
            .onAppear {
                isAnimating = true
                pulse = true
            }
    }
}

// MARK: - Models are defined in GenerationModels.swift

// MARK: - Profile Filter Chip
struct ProfileFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                // Check if icon is an emoji or system icon
                if icon.count == 1 {
                    // It's an emoji avatar
                    Text(icon)
                        .font(.system(size: 14))
                } else {
                    // It's a system icon
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                
                Text(title)
                    .font(AppTypography.captionLarge)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                isSelected ? AppColors.primaryPurple : Color.clear,
                in: Capsule()
            )
            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.clear : AppColors.primaryPurple.opacity(0.3),
                        lineWidth: 1.5
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .shadow(
                color: isSelected ? AppColors.primaryPurple.opacity(0.3) : Color.clear,
                radius: isSelected ? 4 : 0,
                x: 0,
                y: 2
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .childSafeTouchTarget()
    }
}

// MARK: - Preview
#if DEBUG
struct GalleryView_Previews: PreviewProvider {
    static var previews: some View {
        GalleryView()
    }
}
#endif