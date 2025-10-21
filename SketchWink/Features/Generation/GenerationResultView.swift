import SwiftUI
import UIKit

struct GenerationResultView: View {
    let generation: Generation
    @Binding var selectedTab: Int
    let onDismiss: () -> Void
    let onGenerateAnother: () -> Void
    let onDismissParent: () -> Void

    @State private var selectedImageIndex = 0
    @State private var isShowingShareSheet = false
    @State private var isShowingColoringView = false
    @State private var shareableImage: UIImage?
    @State private var isPreparingShare = false
    @State private var showingMoveToFolder = false
    @State private var showingDeleteConfirmation = false
    @State private var isMovingToFolder = false
    @State private var isDeleting = false
    @State private var isDownloading = false
    @State private var error: Error?
    @State private var showingError = false
    @State private var showingToast = false
    @State private var toastMessage = ""
    @State private var toastType: ToastModifier.ToastType = .success
    @Environment(\.dismiss) private var dismiss
    
    private var currentImage: GeneratedImage? {
        generation.images?.indices.contains(selectedImageIndex) == true
            ? generation.images?[selectedImageIndex]
            : generation.images?.first
    }
    
    // MARK: - Dynamic Content Configuration
    private var categoryConfig: CategoryDisplayConfig {
        CategoryDisplayConfig.forCategory(generation.categoryId)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {

                    // Generated Image Display (full width, no padding, no spacing)
                    if let currentImage = currentImage {
                        imageDisplayView(image: currentImage)
                    }

                    // Content with padding
                    VStack(spacing: AppSpacing.sectionSpacing) {
                        // Image Selection (if multiple)
                        if let images = generation.images, images.count > 1 {
                            imageSelectionView(images: images)
                        }

                        // Share Button
                        shareButtonView

                        // Generation Info
                        generationInfoView

                        // Action Buttons
                        actionButtonsView
                    }
                    .pageMargins()
                    .padding(.top, AppSpacing.sectionSpacing)
                    .padding(.bottom, AppSpacing.sectionSpacing)
                }
            }
            .navigationTitle(categoryConfig.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                        onDismiss()
                    }) {
                        ZStack {
                            Circle()
                                .fill(AppColors.surfaceLight)
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(AppColors.borderLight, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            Task { await downloadImageDirectly() }
                        }) {
                            Label("Download to Photos", systemImage: "arrow.down.circle")
                        }
                        .disabled(isDownloading || currentImage == nil)

                        Button(action: {
                            Task { await prepareShare() }
                        }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .disabled(isPreparingShare || currentImage == nil)

                        Button(action: {
                            showingMoveToFolder = true
                        }) {
                            Label("Move to Folder", systemImage: "folder")
                        }
                        .disabled(isMovingToFolder || currentImage == nil)

                        Button(role: .destructive, action: {
                            showingDeleteConfirmation = true
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(AppColors.errorRed)
                        .disabled(isDeleting || currentImage == nil)
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(AppColors.primaryBlue)
                            .frame(width: 36, height: 36)
                    }
                    .disabled(isMovingToFolder || isPreparingShare || isDeleting || isDownloading)
                }
            }
            .toolbarBackground(AppColors.backgroundLight, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .toast(isShowing: $showingToast, message: toastMessage, type: toastType)
        .sheet(isPresented: $isShowingShareSheet) {
            if let shareableImage = shareableImage {
                ActivityViewController(activityItems: [shareableImage])
            }
        }
        .sheet(isPresented: $showingMoveToFolder) {
            if let image = currentImage {
                FolderPickerView(
                    selectedImages: [image.id],
                    onFolderSelected: { folder in
                        Task {
                            await moveImageToFolder(folder: folder, image: image)
                        }
                    }
                )
            }
        }
        .alert("Delete Image", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteCurrentImage()
                }
            }
        } message: {
            Text("Are you sure you want to delete this generated image? This action cannot be undone.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(error?.localizedDescription ?? "Something went wrong. Please try again.")
        }
        .fullScreenCover(isPresented: $isShowingColoringView) {
            if let currentImage = currentImage,
               let imageData = try? Data(contentsOf: URL(string: currentImage.imageUrl)!),
               let uiImage = UIImage(data: imageData) {
                ColoringView(
                    sourceImage: uiImage,
                    originalPrompt: currentImage.generation?.title ?? currentImage.originalUserPrompt ?? "Unknown",
                    onDismiss: {
                        isShowingColoringView = false
                    }
                )
            }
        }
    }
    
    // MARK: - Image Display
    @ViewBuilder
    private func imageDisplayView(image: GeneratedImage) -> some View {
        // Main image with horizontal padding
        AsyncImage(url: URL(string: image.imageUrl)) { imagePhase in
            switch imagePhase {
            case .success(let swiftUIImage):
                swiftUIImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(AppSizing.cornerRadius.lg)
                    .onAppear {
                        // Convert SwiftUI Image to UIImage for sharing
                        Task {
                            if let url = URL(string: image.imageUrl),
                               let data = try? Data(contentsOf: url),
                               let uiImage = UIImage(data: data) {
                                shareableImage = uiImage
                            }
                        }
                    }
            case .failure(_):
                Rectangle()
                    .fill(AppColors.textSecondary.opacity(0.1))
                    .frame(height: 300)
                    .overlay(
                        VStack(spacing: AppSpacing.sm) {
                            Text("📷")
                                .font(.system(size: 40))
                            Text("Image failed to load")
                                .captionLarge()
                                .foregroundColor(AppColors.textSecondary)
                        }
                    )
            case .empty:
                Rectangle()
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
        .padding(.horizontal, AppSpacing.pageMargin)
    }

    // MARK: - Share Button
    private var shareButtonView: some View {
        // Primary share button hidden; sharing is available via the toolbar menu.
        EmptyView()
    }
    
    // MARK: - Image Selection (Multiple Images)
    @ViewBuilder
    private func imageSelectionView(images: [GeneratedImage]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Tap to View")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                        // Use OptimizedImageView for thumbnails
                        OptimizedImageView(
                            url: URL(string: image.imageUrl),
                            size: CGSize(width: 80, height: 80),
                            contentMode: .fill,
                            cornerRadius: AppSizing.cornerRadius.sm
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                .stroke(
                                    selectedImageIndex == index ? categoryConfig.primaryColor : Color.clear,
                                    lineWidth: 3
                                )
                        )
                        .overlay(
                            // Selected indicator
                            Group {
                                if selectedImageIndex == index {
                                    VStack {
                                        HStack {
                                            Spacer()
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(categoryConfig.primaryColor)
                                                .background(
                                                    Circle()
                                                        .fill(Color.white)
                                                        .frame(width: 16, height: 16)
                                                )
                                                .padding(4)
                                        }
                                        Spacer()
                                    }
                                }
                            }
                        )
                        .onTapGesture {
                            selectedImageIndex = index
                            // Reset any active states when switching images
                            shareableImage = nil
                            isPreparingShare = false
                        }
                        .childSafeTouchTarget()
                    }
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Generation Info
    private var generationInfoView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Details")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)

            VStack(spacing: AppSpacing.sm) {
                if let currentImage = currentImage {
                    // Show full prompt (backend now sends complete title without truncation)
                    CopyableDetailRow(
                        label: "Prompt",
                        value: currentImage.generation?.title ?? "Unknown",
                        onCopy: { copiedText in
                            toastMessage = "Prompt copied! 📋"
                            toastType = .success
                            showingToast = true
                        }
                    )

                    DetailRow(
                        label: "Category",
                        value: generation.categoryName ?? currentImage.generation?.category ?? "Unknown"
                    )

                    DetailRow(
                        label: "Style",
                        value: generation.optionName ?? currentImage.generation?.option ?? "Unknown"
                    )

                    DetailRow(
                        label: "Model",
                        value: currentImage.generation?.modelUsed ?? currentImage.modelUsed ?? "Unknown"
                    )

                    DetailRow(
                        label: "Quality",
                        value: (currentImage.generation?.qualityUsed ?? currentImage.qualityUsed ?? "standard").capitalized
                    )

                    DetailRow(
                        label: "Created",
                        value: formatDate(currentImage.createdAt)
                    )
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Action Buttons
    private var actionButtonsView: some View {
        VStack(spacing: AppSpacing.md) {
            // View Gallery
            Button {
                selectedTab = 1 // Switch to Gallery tab (index 1)
                dismiss() // Dismiss GenerationResultView
                onDismiss() // Reset generation state
                onDismissParent() // Dismiss parent GenerationView
            } label: {
                Text("View My Gallery")
                    .largeButtonStyle(
                        backgroundColor: AppColors.primaryBlue
                    )
            }
        }
    }

    // MARK: - Menu Actions
    private func downloadImageDirectly() async {
        guard let image = currentImage else {
            await MainActor.run {
                toastMessage = "No image selected"
                toastType = .error
                showingToast = true
            }
            return
        }

        if await MainActor.run(body: { isDownloading }) {
            return
        }

        await MainActor.run {
            isDownloading = true
        }

        do {
            // Get auth token
            guard let authToken = try KeychainManager.shared.retrieveToken() else {
                throw ImageDownloadError.unauthorized
            }

            // Download as PNG with high quality (95%)
            let data = try await ImageDownloadService.shared.downloadImage(
                imageId: image.id,
                format: .png,
                quality: 95,
                authToken: authToken
            )

            // Save to Photos
            try await ImageDownloadService.shared.saveImageToPhotos(data, format: .png)

            await MainActor.run {
                isDownloading = false
                toastMessage = "Saved to Photos! 📸"
                toastType = .success
                showingToast = true
            }

        } catch let error as ImageDownloadError {
            await MainActor.run {
                isDownloading = false
                toastMessage = error.userFriendlyMessage
                toastType = .error
                showingToast = true
            }
        } catch {
            await MainActor.run {
                isDownloading = false
                toastMessage = "Download failed. Please try again."
                toastType = .error
                showingToast = true
            }
        }
    }

    private func prepareShare() async {
        if await MainActor.run(body: { shareableImage != nil }) {
            await MainActor.run {
                isShowingShareSheet = true
            }
            return
        }

        if await MainActor.run(body: { isPreparingShare }) {
            return
        }

        await MainActor.run {
            isPreparingShare = true
        }

        do {
            let data = try await fetchCurrentImageData()

            guard let uiImage = UIImage(data: data) else {
                throw GenerationResultError.invalidData
            }

            await MainActor.run {
                shareableImage = uiImage
                isShowingShareSheet = true
            }
        } catch {
            await MainActor.run {
                presentError(error)
            }
        }

        await MainActor.run {
            isPreparingShare = false
        }
    }

    private func fetchCurrentImageData() async throws -> Data {
        guard let image = currentImage else {
            throw GenerationResultError.noImageSelected
        }

        guard let url = URL(string: image.imageUrl) else {
            throw GenerationResultError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw GenerationResultError.failedRequest(status: httpResponse.statusCode)
        }

        return data
    }

    private func moveImageToFolder(folder: UserFolder, image: GeneratedImage) async {
        if await MainActor.run(body: { isMovingToFolder }) {
            return
        }

        await MainActor.run {
            isMovingToFolder = true
        }

        do {
            let folderService = FolderService.shared
            _ = try await folderService.moveImagesToFolder(
                folderId: folder.id,
                imageIds: [image.id]
            )

            await MainActor.run {
                isMovingToFolder = false
                showingMoveToFolder = false
            }
        } catch {
            await MainActor.run {
                isMovingToFolder = false
                showingMoveToFolder = false
                presentError(error)
            }
        }
    }

    private func deleteCurrentImage() async {
        guard let image = currentImage else {
            await MainActor.run {
                presentError(GenerationResultError.noImageSelected)
            }
            return
        }

        if await MainActor.run(body: { isDeleting }) {
            return
        }

        await MainActor.run {
            isDeleting = true
        }

        do {
            try await GenerationService.shared.deleteImage(imageId: image.id)

            await MainActor.run {
                isDeleting = false
                showingDeleteConfirmation = false
                dismiss()
                onDismiss()
            }
        } catch {
            await MainActor.run {
                isDeleting = false
                showingDeleteConfirmation = false
                presentError(error)
            }
        }
    }

    private func presentError(_ error: Error) {
        self.error = error
        showingError = true
    }

    // MARK: - Helper Methods
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

        // Last resort: return original string
        return dateString
    }
}

private enum GenerationResultError: LocalizedError {
    case noImageSelected
    case invalidURL
    case failedRequest(status: Int)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .noImageSelected:
            return "No generated image is currently selected."
        case .invalidURL:
            return "We couldn't access the generated image."
        case .failedRequest(let status):
            return "The server responded with status code \(status). Please try again."
        case .invalidData:
            return "The generated image data appears to be corrupted."
        }
    }
}

// MARK: - Category Display Configuration
struct CategoryDisplayConfig {
    let navigationTitle: String
    let successEmoji: String
    let successTitle: String
    let successDescription: String
    let primaryColor: Color
    let showColoringButton: Bool
    let actionButtonEmoji: String
    let actionButtonTitle: String
    let generateAnotherEmoji: String
    let generateAnotherTitle: String
    
    static func forCategory(_ categoryId: String) -> CategoryDisplayConfig {
        switch categoryId {
        case "coloring_pages":
            return CategoryDisplayConfig(
                navigationTitle: "Your Coloring Page",
                successEmoji: "🎉",
                successTitle: "Coloring Page Created!",
                successDescription: "Your AI-generated coloring page is ready to enjoy!",
                primaryColor: AppColors.coloringPagesColor,
                showColoringButton: true,
                actionButtonEmoji: "🎨",
                actionButtonTitle: "Color",
                generateAnotherEmoji: "🎨",
                generateAnotherTitle: "Create Another Coloring Page"
            )
        case "stickers":
            return CategoryDisplayConfig(
                navigationTitle: "Your Sticker",
                successEmoji: "✨",
                successTitle: "Sticker Created!",
                successDescription: "Your AI-generated sticker is ready to use!",
                primaryColor: AppColors.stickersColor,
                showColoringButton: false,
                actionButtonEmoji: "🎯",
                actionButtonTitle: "Use",
                generateAnotherEmoji: "✨",
                generateAnotherTitle: "Create Another Sticker"
            )
        case "wallpapers":
            return CategoryDisplayConfig(
                navigationTitle: "Your Wallpaper",
                successEmoji: "🌟",
                successTitle: "Wallpaper Created!",
                successDescription: "Your AI-generated wallpaper is ready to set!",
                primaryColor: AppColors.wallpapersColor,
                showColoringButton: false,
                actionButtonEmoji: "📱",
                actionButtonTitle: "Set",
                generateAnotherEmoji: "🌟",
                generateAnotherTitle: "Create Another Wallpaper"
            )
        case "mandalas":
            return CategoryDisplayConfig(
                navigationTitle: "Your Mandala",
                successEmoji: "🕉️",
                successTitle: "Mandala Created!",
                successDescription: "Your AI-generated mandala is ready for mindful coloring!",
                primaryColor: AppColors.mandalasColor,
                showColoringButton: true,
                actionButtonEmoji: "🧘",
                actionButtonTitle: "Color",
                generateAnotherEmoji: "🕉️",
                generateAnotherTitle: "Create Another Mandala"
            )
        default:
            // Fallback to coloring pages
            return CategoryDisplayConfig(
                navigationTitle: "Your Creation",
                successEmoji: "🎉",
                successTitle: "Content Created!",
                successDescription: "Your AI-generated content is ready!",
                primaryColor: AppColors.primaryBlue,
                showColoringButton: false,
                actionButtonEmoji: "✨",
                actionButtonTitle: "View",
                generateAnotherEmoji: "🎨",
                generateAnotherTitle: "Create Another"
            )
        }
    }
}

// MARK: - Activity View Controller
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
