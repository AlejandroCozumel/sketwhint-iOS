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
    @Environment(\.dismiss) private var dismiss
    
    private let columns = [
        GridItem(.flexible(), spacing: AppSpacing.grid.itemSpacing),
        GridItem(.flexible(), spacing: AppSpacing.grid.itemSpacing)
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
            
            // Images grid
            LazyVGrid(columns: columns, spacing: AppSpacing.grid.rowSpacing) {
                ForEach(images) { image in
                    GalleryImageCard(image: image) {
                        selectedImage = image
                    }
                }
                
                // Load more indicator
                if hasMorePages {
                    loadMoreView
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
                
                Text("\(images.count) image\(images.count == 1 ? "" : "s")")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            // Categories filter could go here in the future
        }
        .cardStyle()
    }
    
    // MARK: - Load More View
    private var loadMoreView: some View {
        VStack(spacing: AppSpacing.sm) {
            if isLoading {
                ProgressView()
                    .tint(AppColors.primaryBlue)
            } else {
                Button("Load More") {
                    Task {
                        await loadMoreImages()
                    }
                }
                .font(AppTypography.titleMedium)
                .foregroundColor(AppColors.primaryBlue)
            }
        }
        .frame(height: 100)
        .onAppear {
            if !isLoading {
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
                hasMorePages = response.pagination.hasNext
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
                hasMorePages = response.pagination.hasNext
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
        return try await generationService.getUserImages(page: page, limit: 20)
    }
}

// MARK: - Supporting Views
struct GalleryImageCard: View {
    let image: GeneratedImage
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            AsyncImage(url: URL(string: image.imageUrl)) { imagePhase in
                switch imagePhase {
                case .success(let swiftUIImage):
                    swiftUIImage
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 160)
                        .clipped()
                        .cornerRadius(AppSizing.cornerRadius.md)
                        .overlay(
                            // Favorite indicator
                            VStack {
                                HStack {
                                    Spacer()
                                    if image.isFavorite {
                                        Text("❤️")
                                            .font(.system(size: 20))
                                            .padding(AppSpacing.xs)
                                            .background(Color.black.opacity(0.6))
                                            .cornerRadius(AppSizing.cornerRadius.sm)
                                    }
                                }
                                Spacer()
                            }
                            .padding(AppSpacing.xs)
                        )
                case .failure(_):
                    RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                        .fill(AppColors.textSecondary.opacity(0.1))
                        .frame(height: 160)
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
                        .frame(height: 160)
                        .overlay(
                            ProgressView()
                                .tint(AppColors.primaryBlue)
                        )
                @unknown default:
                    EmptyView()
                }
            }
        }
        .childSafeTouchTarget()
    }
}

// MARK: - Image Detail View (Simple)
struct ImageDetailView: View {
    let image: GeneratedImage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    
                    // Full size image
                    AsyncImage(url: URL(string: image.imageUrl)) { imagePhase in
                        switch imagePhase {
                        case .success(let swiftUIImage):
                            swiftUIImage
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(AppSizing.cornerRadius.lg)
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
                            DetailRow(label: "Prompt", value: image.originalUserPrompt)
                            DetailRow(label: "Created", value: formatDate(image.createdAt))
                            if image.wasEnhanced {
                                DetailRow(label: "AI Enhanced", value: "Yes ✨")
                            }
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

// MARK: - Models are defined in GenerationModels.swift

// MARK: - Preview
#if DEBUG
struct GalleryView_Previews: PreviewProvider {
    static var previews: some View {
        GalleryView()
    }
}
#endif