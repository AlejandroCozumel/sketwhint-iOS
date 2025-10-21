import SwiftUI

// MARK: - Book Generation State
enum BookGenerationState {
    case idle
    case generating(String) // bookId
    case completed(String) // bookId  
    case failed(String)
    
    var isGenerating: Bool {
        if case .generating = self { return true }
        return false
    }
    
    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }
}

struct BookGenerationView: View {
    @StateObject private var draftService = DraftService.shared
    @State private var selectedModel = "seedream"
    @State private var selectedQuality = "standard"
    @State private var selectedDimensions = "a4"
    @State private var bookGenerationState: BookGenerationState = .idle
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showingError = false
    
    let draft: StoryDraft
    let productCategory: ProductCategory
    let onDismiss: () -> Void
    
    init(draft: StoryDraft, productCategory: ProductCategory, onDismiss: @escaping () -> Void) {
        self.draft = draft
        self.productCategory = productCategory
        self.onDismiss = onDismiss
        
        #if DEBUG
        print("📖 BookGenerationView: init() called for draft: \(draft.title)")
        #endif
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    if isLoading {
                        loadingView
                    } else {
                        bookGenerationFormView
                    }
                }
                .pageMargins()
                .padding(.vertical, AppSpacing.sectionSpacing)
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("Generate Book")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.primaryBlue)
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(error?.localizedDescription ?? "An unknown error occurred")
        }
        .fullScreenCover(isPresented: .constant(bookGenerationState.isGenerating)) {
            if case .generating(let bookId) = bookGenerationState {
                BookGenerationProgressView(
                    bookId: bookId,
                    draftTitle: draft.title,
                    onComplete: { completedBookId in
                        bookGenerationState = .completed(completedBookId)
                    },
                    onError: { errorMessage in
                        bookGenerationState = .failed(errorMessage)
                        error = DraftError.serverError(errorMessage)
                        showingError = true
                    }
                )
            }
        }
        .sheet(isPresented: bookResultBinding) {
            if case .completed(let bookId) = bookGenerationState {
                BookCompletedView(
                    bookId: bookId,
                    draftTitle: draft.title,
                    onDismiss: {
                        bookGenerationState = .idle
                        onDismiss()
                    }
                )
            }
        }
    }

    private var bookResultBinding: Binding<Bool> {
        Binding(
            get: {
                if case .completed = bookGenerationState {
                    return true
                }
                return false
            },
            set: { presented in
                if !presented, case .completed = bookGenerationState {
                    bookGenerationState = .idle
                    onDismiss()
                }
            }
        )
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: AppSpacing.xl) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppColors.primaryBlue)
            
            Text("Preparing book generation...")
                .font(AppTypography.bodyLarge)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 200)
    }
    
    // MARK: - Book Generation Form
    @ViewBuilder
    private var bookGenerationFormView: some View {
        VStack(spacing: AppSpacing.sectionSpacing) {
            // Draft Summary
            draftSummaryView
            
            // Quality Selection
            qualitySelectionView
            
            // Model Selection
            modelSelectionView
            
            // Dimensions Selection
            dimensionsSelectionView
            
            // Generate Book Button
            generateBookButtonView
        }
    }
    
    // MARK: - Draft Summary
    @ViewBuilder
    private var draftSummaryView: some View {
        VStack(spacing: AppSpacing.md) {
            Text(productCategory.icon)
                .font(.system(size: AppSizing.iconSizes.xxl))
            
            VStack(spacing: AppSpacing.xs) {
                Text(draft.title)
                    .headlineLarge()
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Ready to generate \(draft.storyOutline.pages.count) illustrated pages")
                    .bodyMedium()
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                
                // Token cost info
                HStack(spacing: AppSpacing.md) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(AppColors.warningOrange)
                            .font(.system(size: 12))
                        Text("\(draft.storyOutline.pages.count * 2) tokens for images")
                            .captionLarge()
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(AppColors.infoBlue)
                            .font(.system(size: 12))
                        Text(productCategory.estimatedDuration)
                            .captionLarge()
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .padding(AppSpacing.cardPadding.inner)
        .background(productColor.opacity(0.1))
        .cornerRadius(AppSizing.cornerRadius.md)
        .shadow(
            color: Color.black.opacity(AppSizing.shadows.small.opacity),
            radius: AppSizing.shadows.small.radius,
            x: AppSizing.shadows.small.x,
            y: AppSizing.shadows.small.y
        )
    }
    
    // MARK: - Quality Selection
    private var qualitySelectionView: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Image Quality")
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Higher quality takes more time")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
            }
            
            VStack(spacing: AppSpacing.xs) {
                ForEach(["standard", "high", "ultra"], id: \.self) { quality in
                    Button(action: {
                        selectedQuality = quality
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                                Text(quality.capitalized)
                                    .font(AppTypography.titleMedium)
                                    .foregroundColor(selectedQuality == quality ? AppColors.primaryBlue : AppColors.textPrimary)
                                
                                Text(qualityDescription(quality))
                                    .font(AppTypography.captionMedium)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            if selectedQuality == quality {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.primaryBlue)
                                    .font(.system(size: 20))
                            }
                        }
                        .padding(AppSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                .fill(selectedQuality == quality ? AppColors.primaryBlue.opacity(0.1) : AppColors.backgroundLight)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                .stroke(
                                    selectedQuality == quality ? AppColors.primaryBlue : AppColors.textSecondary.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                    }
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Model Selection
    private var modelSelectionView: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("AI Model")
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Choose the AI model for your book illustrations")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
            }
            
            VStack(spacing: AppSpacing.xs) {
                ForEach(["seedream", "gemini", "flux"], id: \.self) { model in
                    Button(action: {
                        selectedModel = model
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                                Text(model.capitalized)
                                    .font(AppTypography.titleMedium)
                                    .foregroundColor(selectedModel == model ? AppColors.primaryBlue : AppColors.textPrimary)
                                
                                Text(modelDescription(model))
                                    .font(AppTypography.captionMedium)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            if selectedModel == model {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.primaryBlue)
                                    .font(.system(size: 20))
                            }
                        }
                        .padding(AppSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                .fill(selectedModel == model ? AppColors.primaryBlue.opacity(0.1) : AppColors.backgroundLight)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                .stroke(
                                    selectedModel == model ? AppColors.primaryBlue : AppColors.textSecondary.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                    }
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Dimensions Selection
    private var dimensionsSelectionView: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Page Format")
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("A4 format is recommended for books")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
            }
            
            HStack(spacing: AppSpacing.sm) {
                ForEach(["a4", "2:3", "1:1"], id: \.self) { dimension in
                    let isRecommended = dimension == "a4"
                    
                    Button(action: {
                        selectedDimensions = dimension
                    }) {
                        VStack(spacing: AppSpacing.xxs) {
                            Text(dimension.uppercased())
                                .font(AppTypography.titleMedium)
                                .foregroundColor(selectedDimensions == dimension ? .white : AppColors.textPrimary)
                            
                            Text(dimensionDescription(dimension))
                                .font(AppTypography.captionSmall)
                                .foregroundColor(selectedDimensions == dimension ? .white.opacity(0.8) : AppColors.textSecondary)
                            
                            if isRecommended {
                                Text("✓ Best")
                                    .font(AppTypography.captionSmall)
                                    .foregroundColor(selectedDimensions == dimension ? .white.opacity(0.8) : AppColors.successGreen)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 70)
                        .background(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                .fill(selectedDimensions == dimension ? AppColors.primaryBlue : AppColors.backgroundLight)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                .stroke(
                                    selectedDimensions == dimension ? AppColors.primaryBlue : (isRecommended ? AppColors.successGreen.opacity(0.3) : AppColors.textSecondary.opacity(0.2)),
                                    lineWidth: 1
                                )
                        )
                    }
                }
                
                Spacer()
            }
        }
        .cardStyle()
    }
    
    // MARK: - Generate Book Button
    private var generateBookButtonView: some View {
        VStack(spacing: AppSpacing.sm) {
            Button("Generate Book") {
                Task {
                    await generateBook()
                }
            }
            .largeButtonStyle(backgroundColor: productColor)
            .childSafeTouchTarget()
            
            Text("This will create \(draft.storyOutline.pages.count) illustrated pages")
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Computed Properties
    private var productColor: Color {
        if !productCategory.color.isEmpty {
            return Color(hex: productCategory.color)
        }
        
        switch productCategory.productType {
        case "book": return Color(hex: "#D97706") // Amber-600
        default: return AppColors.primaryBlue
        }
    }
    
    // MARK: - Methods
    private func generateBook() async {
        let options = GenerateBookFromDraftRequest(
            model: selectedModel,
            quality: selectedQuality,
            dimensions: selectedDimensions
        )
        
        #if DEBUG
        print("📖 BookGenerationView: Generating book from draft \(draft.id)")
        print("📖 Options: model=\(selectedModel), quality=\(selectedQuality), dimensions=\(selectedDimensions)")
        #endif
        
        do {
            let response = try await draftService.generateBookFromDraft(draftId: draft.id, options: options)
            bookGenerationState = .generating(response.productId)
        } catch {
            self.error = error
            showingError = true
        }
    }
    
    // MARK: - Helper Methods
    private func qualityDescription(_ quality: String) -> String {
        switch quality {
        case "standard": return "Good quality, faster generation"
        case "high": return "Better quality, slower generation"
        case "ultra": return "Best quality, longest generation time"
        default: return ""
        }
    }
    
    private func modelDescription(_ model: String) -> String {
        switch model {
        case "seedream": return "Advanced model with high-quality illustrations"
        case "gemini": return "Balanced speed and quality"
        case "flux": return "Fast generation with good quality"
        default: return ""
        }
    }
    
    private func dimensionDescription(_ dimension: String) -> String {
        switch dimension {
        case "a4": return "Book format"
        case "2:3": return "Portrait"
        case "1:1": return "Square"
        default: return ""
        }
    }
}

// MARK: - Placeholder Views
struct BookGenerationProgressView: View {
    let bookId: String
    let draftTitle: String
    let onComplete: (String) -> Void
    let onError: (String) -> Void
    
    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppColors.primaryBlue)
            
            Text("Creating your book...")
                .headlineMedium()
                .foregroundColor(AppColors.textPrimary)
            
            Text("AI is illustrating \"\(draftTitle)\"")
                .bodyMedium()
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundLight)
    }
}

struct BookCompletedView: View {
    let bookId: String
    let draftTitle: String
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: AppSpacing.xl) {
                Text("🎉")
                    .font(.system(size: 80))
                
                VStack(spacing: AppSpacing.md) {
                    Text("Book Complete!")
                        .headlineLarge()
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("\"\(draftTitle)\" is ready to read")
                        .bodyMedium()
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                Button("View in Books") {
                    onDismiss()
                }
                .largeButtonStyle(backgroundColor: AppColors.primaryBlue)
                .childSafeTouchTarget()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.backgroundLight)
            .navigationTitle("Success")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
}
