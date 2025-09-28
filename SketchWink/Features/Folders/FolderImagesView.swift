import SwiftUI

struct FolderImagesView: View {
    let folder: UserFolder
    @Environment(\.dismiss) private var dismiss
    @StateObject private var folderService = FolderService.shared
    
    @State private var images: [FolderImage] = []
    @State private var isLoading = true
    @State private var currentPage = 1
    @State private var hasMorePages = false
    @State private var totalImages = 0
    @State private var errorMessage: String?
    @State private var selectedImages: Set<String> = []
    @State private var isSelectionMode = false
    @State private var showingRemoveConfirmation = false
    
    private let pageLimit = 20
    
    // MARK: - Computed Properties for Empty States
    private var emptyStateTitle: String {
        if totalImages == 0 && !isLoading {
            return "Empty Folder"
        } else {
            return "No Images for Current Profile"
        }
    }
    
    private var emptyStateMessage: String {
        if totalImages == 0 && !isLoading {
            return "Move images from your gallery to organize them in this folder"
        } else {
            return "This folder doesn't have any images for the current family member"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Folder info header
                folderInfoHeader
                
                // Content
                if isLoading && images.isEmpty {
                    loadingView
                } else if images.isEmpty {
                    emptyStateView
                } else {
                    imageGridView
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
                await loadImages()
            }
            .refreshable {
                await refreshImages()
            }
            .alert("Remove Images", isPresented: $showingRemoveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    Task { await removeSelectedImages() }
                }
            } message: {
                Text("Remove \(selectedImages.count) image\(selectedImages.count == 1 ? "" : "s") from this folder? The images will return to your main gallery.")
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
    
    // MARK: - Image Grid View
    private var imageGridView: some View {
        ScrollView {
            LazyVGrid(columns: GridLayouts.threeColumnGrid, spacing: AppSpacing.grid.itemSpacing) {
                ForEach(images, id: \.id) { image in
                    FolderImageCard(
                        image: image,
                        isSelected: selectedImages.contains(image.id),
                        isSelectionMode: isSelectionMode,
                        onTap: {
                            if isSelectionMode {
                                toggleImageSelection(image.id)
                            } else {
                                // Open image detail or full screen view
                                print("📱 Opening image detail for: \(image.id)")
                            }
                        },
                        onLongPress: {
                            if !isSelectionMode {
                                isSelectionMode = true
                                selectedImages.insert(image.id)
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
            
            Button(action: { dismiss() }) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Go to Gallery")
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
            let response = try await folderService.getFolderImages(
                folderId: folder.id,
                page: 1,
                limit: pageLimit
            )
            
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
        currentPage = 1
        await loadImages()
    }
    
    private func loadMoreImages() async {
        guard hasMorePages && !isLoading else { return }
        
        do {
            let nextPage = currentPage + 1
            let response = try await folderService.getFolderImages(
                folderId: folder.id,
                page: nextPage,
                limit: pageLimit
            )
            
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
}

// MARK: - Folder Image Card
struct FolderImageCard: View {
    let image: FolderImage
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Image
                AsyncImage(url: URL(string: image.imageUrl)) { imagePhase in
                    switch imagePhase {
                    case .success(let uiImage):
                        uiImage
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure(_):
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(AppColors.textSecondary)
                    case .empty:
                        ProgressView()
                            .scaleEffect(0.8)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Selection overlay
                if isSelectionMode {
                    VStack {
                        HStack {
                            Spacer()
                            
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundColor(isSelected ? AppColors.primaryBlue : .white)
                                .background(
                                    Circle()
                                        .fill(isSelected ? .white : Color.black.opacity(0.3))
                                        .frame(width: 24, height: 24)
                                )
                                .padding(.top, AppSpacing.xs)
                                .padding(.trailing, AppSpacing.xs)
                        }
                        
                        Spacer()
                    }
                }
                
                // Favorite indicator
                if image.isFavorite {
                    VStack {
                        Spacer()
                        
                        HStack {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.errorRed)
                                .background(
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 18, height: 18)
                                )
                                .padding(.leading, AppSpacing.xs)
                                .padding(.bottom, AppSpacing.xs)
                            
                            Spacer()
                        }
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected ? AppColors.primaryBlue : Color.clear,
                    lineWidth: isSelected ? 2 : 0
                )
        )
        .onLongPressGesture(minimumDuration: 0.5) {
            onLongPress()
        } onPressingChanged: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }
    }
}

#Preview {
    FolderImagesView(
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
        )
    )
}