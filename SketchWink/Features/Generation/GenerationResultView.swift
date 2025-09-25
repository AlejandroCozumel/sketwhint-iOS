import SwiftUI

struct GenerationResultView: View {
    let generation: Generation
    let onDismiss: () -> Void
    let onGenerateAnother: () -> Void
    
    @State private var selectedImageIndex = 0
    @State private var isShowingShareSheet = false
    @State private var isShowingColoringView = false
    @State private var shareableImage: UIImage?
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
            .navigationTitle(categoryConfig.navigationTitle)
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
                    .fill(categoryConfig.primaryColor)
                    .frame(width: 100, height: 100)
                    .shadow(
                        color: categoryConfig.primaryColor.opacity(0.3),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
                
                Text(categoryConfig.successEmoji)
                    .font(.system(size: 50))
            }
            
            VStack(spacing: AppSpacing.sm) {
                Text(categoryConfig.successTitle)
                    .font(AppTypography.headlineLarge)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(categoryConfig.successDescription)
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
            
            // Image actions - Only Share button (full width)
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
            .childSafeTouchTarget()
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
                                                selectedImageIndex == index ? categoryConfig.primaryColor : Color.clear,
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
                    Text(categoryConfig.generateAnotherEmoji)
                    Text(categoryConfig.generateAnotherTitle)
                        .font(AppTypography.titleMedium)
                }
            }
            .largeButtonStyle(backgroundColor: categoryConfig.primaryColor)
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