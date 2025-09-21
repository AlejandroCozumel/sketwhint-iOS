import SwiftUI

struct GalleryView: View {
    @StateObject private var generationService = GenerationService.shared
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
    
    // Categories from backend
    @State private var availableCategories: [CategoryWithOptions] = []
    @State private var isLoadingCategories = false
    
    @Environment(\.dismiss) private var dismiss
    
    private let columns = [
        GridItem(.flexible(minimum: 100, maximum: .infinity), spacing: AppSpacing.grid.itemSpacing),
        GridItem(.flexible(minimum: 100, maximum: .infinity), spacing: AppSpacing.grid.itemSpacing)
    ]
    
    var body: some View {
        NavigationView {
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
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("My Gallery")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.primaryBlue)
                }
            }
        }
        .task {
            await loadCategories()
            await loadImages()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(error?.localizedDescription ?? "An unknown error occurred")
        }
        .sheet(item: $selectedImage) { image in
            ImageDetailView(image: image)
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
            Text("🎨")
                .font(.system(size: 80))
            
            VStack(spacing: AppSpacing.md) {
                Text("No Creations Yet")
                    .font(AppTypography.headlineLarge)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Start creating amazing coloring pages, stickers, and more! Your generated art will appear here.")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                
                Button("Create Your First Art") {
                    dismiss()
                    // This will return to MainAppView where they can tap Create Art
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
            
            // Filters UI
            filtersView
            
            // Images grid with smooth skeleton overlay
            ZStack {
                // Current images (fade out smoothly during loading)
                LazyVGrid(columns: columns, spacing: AppSpacing.grid.rowSpacing) {
                    ForEach(images.indices, id: \.self) { index in
                        GalleryImageCard(
                            image: $images[index],
                            action: {
                                selectedImage = images[index]
                            },
                            onFavoriteToggle: { imageToToggle in
                                await toggleImageFavorite(imageToToggle, at: index)
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
    
    // MARK: - Filters View
    private var filtersView: some View {
        VStack(spacing: AppSpacing.md) {
            
            // Search Bar
            searchBarView
            
            // All/Favorites Toggle
            favoritesToggleView
            
            // Category Filters
            categoryFiltersView
        }
        .cardStyle()
    }
    
    // MARK: - Search Bar
    private var searchBarView: some View {
        HStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Text("🔍")
                    .font(.system(size: 16))
                
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
                        Text("✕")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .childSafeTouchTarget()
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.surfaceLight)
            .cornerRadius(AppSizing.cornerRadius.lg)
            
            Button("Search") {
                applyFilters()
            }
            .font(AppTypography.captionLarge)
            .foregroundColor(AppColors.primaryBlue)
            .opacity(searchText.isEmpty ? 0.6 : 1.0)
        }
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
                            color: parseColor(category.color),
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
            search: search
        )
    }
    
    // MARK: - Filter Application
    private func applyFilters() {
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
    private func parseColor(_ colorString: String?) -> Color? {
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
}

// MARK: - Supporting Views
struct GalleryImageCard: View {
    @Binding var image: GeneratedImage
    let action: () -> Void
    let onFavoriteToggle: (GeneratedImage) async -> Void
    
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
                        .overlay(
                            // Favorite toggle button - TOP RIGHT
                            AnimatedFavoriteButton(
                                isFavorite: image.isFavorite,
                                onToggle: {
                                    Task {
                                        await onFavoriteToggle(image)
                                    }
                                }
                            )
                            .padding(AppSpacing.xs),
                            alignment: .topTrailing
                        )
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
        .childSafeTouchTarget()
    }
}

// MARK: - Image Detail View (Simple)
struct ImageDetailView: View {
    @State private var image: GeneratedImage
    @StateObject private var generationService = GenerationService.shared
    @State private var isTogglingFavorite = false
    @State private var error: Error?
    @State private var showingError = false
    @Environment(\.dismiss) private var dismiss
    
    init(image: GeneratedImage) {
        self._image = State(initialValue: image)
    }
    
    var body: some View {
        NavigationView {
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
                            DetailRow(label: "Created", value: formatDate(image.createdAt))
                        }
                    }
                    .cardStyle()
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
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(error?.localizedDescription ?? "Failed to update favorite status")
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

// MARK: - Preview
#if DEBUG
struct GalleryView_Previews: PreviewProvider {
    static var previews: some View {
        GalleryView()
    }
}
#endif