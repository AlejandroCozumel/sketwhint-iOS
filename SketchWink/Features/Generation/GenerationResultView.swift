import SwiftUI
import Photos

struct GenerationResultView: View {
    let generation: Generation
    let onDismiss: () -> Void
    let onGenerateAnother: () -> Void
    
    @State private var selectedImageIndex = 0
    @State private var isShowingShareSheet = false
    @State private var isShowingColoringView = false
    @State private var shareableImage: UIImage?
    @State private var showingSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var isProcessing = false
    @Environment(\.dismiss) private var dismiss
    
    private var currentImage: GeneratedImage? {
        generation.images?.indices.contains(selectedImageIndex) == true
            ? generation.images?[selectedImageIndex]
            : generation.images?.first
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    
                    // Success Header
                    successHeaderView
                    
                    // Generated Image Display
                    if let currentImage = currentImage {
                        imageDisplayView(image: currentImage)
                    }
                    
                    // Image Selection (if multiple)
                    if let images = generation.images, images.count > 1 {
                        imageSelectionView(images: images)
                    }
                    
                    // Generation Info
                    generationInfoView
                    
                    // Action Buttons
                    actionButtonsView
                }
                .pageMargins()
                .padding(.vertical, AppSpacing.sectionSpacing)
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("Your Coloring Page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                        onDismiss()
                    }
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.primaryBlue)
                }
            }
        }
        .alert("Save Result", isPresented: $showingSaveAlert) {
            Button("OK") { }
        } message: {
            Text(saveAlertMessage)
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let shareableImage = shareableImage {
                ActivityViewController(activityItems: [shareableImage])
            }
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
    
    // MARK: - Success Header
    private var successHeaderView: some View {
        VStack(spacing: AppSpacing.lg) {
            // Success animation
            ZStack {
                Circle()
                    .fill(AppColors.coloringPagesColor)
                    .frame(width: 100, height: 100)
                    .shadow(
                        color: AppColors.coloringPagesColor.opacity(0.3),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
                
                Text("🎉")
                    .font(.system(size: 50))
            }
            
            VStack(spacing: AppSpacing.sm) {
                Text("Coloring Page Created!")
                    .font(AppTypography.headlineLarge)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Your AI-generated coloring page is ready to enjoy!")
                    .font(AppTypography.bodyLarge)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .cardStyle()
    }
    
    // MARK: - Image Display
    @ViewBuilder
    private func imageDisplayView(image: GeneratedImage) -> some View {
        VStack(spacing: AppSpacing.md) {
            
            // Main image
            AsyncImage(url: URL(string: image.imageUrl)) { imagePhase in
                switch imagePhase {
                case .success(let swiftUIImage):
                    swiftUIImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(AppSizing.cornerRadius.lg)
                        .shadow(
                            color: AppColors.textPrimary.opacity(0.1),
                            radius: 10,
                            x: 0,
                            y: 5
                        )
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
                    RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
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
            .frame(maxHeight: 400)
            
            // Image actions
            HStack(spacing: AppSpacing.md) {
                // Save to Photos
                Button {
                    Task {
                        await saveToPhotos(imageUrl: image.imageUrl)
                    }
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Text("📸")
                        Text("Save")
                            .font(AppTypography.titleMedium)
                    }
                }
                .largeButtonStyle(backgroundColor: AppColors.primaryBlue)
                .disabled(isProcessing)
                
                // Share
                Button {
                    isShowingShareSheet = true
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Text("📤")
                        Text("Share")
                            .font(AppTypography.titleMedium)
                    }
                }
                .largeButtonStyle(backgroundColor: AppColors.primaryPurple)
                .disabled(shareableImage == nil)
                
                // Start Coloring
                Button {
                    isShowingColoringView = true
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Text("🎨")
                        Text("Color")
                            .font(AppTypography.titleMedium)
                    }
                }
                .largeButtonStyle(backgroundColor: AppColors.coloringPagesColor)
            }
        }
        .cardStyle()
    }
    
    // MARK: - Image Selection (Multiple Images)
    @ViewBuilder
    private func imageSelectionView(images: [GeneratedImage]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Choose Your Favorite")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.md) {
                    ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                        AsyncImage(url: URL(string: image.imageUrl)) { imagePhase in
                            switch imagePhase {
                            case .success(let swiftUIImage):
                                swiftUIImage
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipped()
                                    .cornerRadius(AppSizing.cornerRadius.sm)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                            .stroke(
                                                selectedImageIndex == index ? AppColors.coloringPagesColor : Color.clear,
                                                lineWidth: 3
                                            )
                                    )
                            case .failure(_), .empty:
                                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                    .fill(AppColors.textSecondary.opacity(0.1))
                                    .frame(width: 80, height: 80)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .onTapGesture {
                            selectedImageIndex = index
                        }
                        .childSafeTouchTarget()
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
            }
        }
        .cardStyle()
    }
    
    // MARK: - Generation Info
    private var generationInfoView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Creation Details")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
            
            VStack(spacing: AppSpacing.sm) {
                if let currentImage = currentImage {
                    GenerationInfoRow(
                        label: "Title",
                        value: currentImage.generation?.title ?? currentImage.originalUserPrompt ?? "Unknown",
                        isExpandable: true
                    )
                    
                    GenerationInfoRow(
                        label: "Category",
                        value: generation.categoryName ?? currentImage.generation?.category ?? "Unknown"
                    )
                    
                    GenerationInfoRow(
                        label: "Style",
                        value: generation.optionName ?? currentImage.generation?.option ?? "Unknown"
                    )
                    
                    GenerationInfoRow(
                        label: "Model",
                        value: currentImage.generation?.modelUsed ?? currentImage.modelUsed ?? "Unknown"
                    )
                    
                    GenerationInfoRow(
                        label: "Quality",
                        value: (currentImage.generation?.qualityUsed ?? currentImage.qualityUsed ?? "standard").capitalized
                    )
                    
                    GenerationInfoRow(
                        label: "Created",
                        value: formatDate(currentImage.createdAt)
                    )
                }
                
                // Note: Enhancement info not available in current API response
            }
        }
        .cardStyle()
    }
    
    // MARK: - Action Buttons
    private var actionButtonsView: some View {
        VStack(spacing: AppSpacing.md) {
            // Generate Another
            Button {
                dismiss()
                onGenerateAnother()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Text("🎨")
                    Text("Create Another Coloring Page")
                        .font(AppTypography.titleMedium)
                }
            }
            .largeButtonStyle(backgroundColor: AppColors.coloringPagesColor)
            .childSafeTouchTarget()
            
            // View Gallery
            Button {
                dismiss()
                onDismiss()
                // Gallery will be accessible from MainAppView
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Text("🖼️")
                    Text("View My Gallery")
                        .font(AppTypography.titleMedium)
                }
            }
            .largeButtonStyle(backgroundColor: AppColors.wallpapersColor)
            .childSafeTouchTarget()
        }
    }
    
    // MARK: - Helper Methods
    private func saveToPhotos(imageUrl: String) async {
        isProcessing = true
        
        do {
            guard let url = URL(string: imageUrl) else {
                throw SaveError.invalidURL
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let uiImage = UIImage(data: data) else {
                throw SaveError.invalidImageData
            }
            
            // Request photo library permission
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            
            guard status == .authorized else {
                throw SaveError.permissionDenied
            }
            
            // Save to photo library
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
            }
            
            await MainActor.run {
                saveAlertMessage = "Coloring page saved to Photos! 📸"
                showingSaveAlert = true
            }
            
        } catch {
            await MainActor.run {
                saveAlertMessage = "Failed to save: \(error.localizedDescription)"
                showingSaveAlert = true
            }
        }
        
        isProcessing = false
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

// MARK: - Supporting Views
struct GenerationInfoRow: View {
    let label: String
    let value: String
    let isExpandable: Bool
    
    @State private var isExpanded = false
    
    init(label: String, value: String, isExpandable: Bool = false) {
        self.label = label
        self.value = value
        self.isExpandable = isExpandable
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(label + ":")
                    .font(AppTypography.titleSmall)
                    .foregroundColor(AppColors.textSecondary)
                
                Spacer()
                
                if isExpandable && value.count > 50 {
                    Button(isExpanded ? "Show Less" : "Show More") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    }
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.primaryBlue)
                }
            }
            
            Text(isExpandable && !isExpanded && value.count > 50 
                 ? String(value.prefix(50)) + "..."
                 : value)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.leading)
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

// MARK: - Save Errors
enum SaveError: LocalizedError {
    case invalidURL
    case invalidImageData
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid image URL"
        case .invalidImageData:
            return "Invalid image data"
        case .permissionDenied:
            return "Photo library permission denied"
        }
    }
}