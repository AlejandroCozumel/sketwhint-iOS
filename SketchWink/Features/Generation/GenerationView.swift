import SwiftUI

struct GenerationView: View {
    @StateObject private var generationService = GenerationService.shared
    @State private var selectedCategory: CategoryWithOptions?
    @State private var selectedOption: GenerationOption?
    @State private var userPrompt = ""
    @State private var promptEnhancementEnabled = true
    @State private var generationState: GenerationState = .idle
    @State private var isLoading = true
    @State private var error: Error?
    @State private var showingError = false
    
    let preselectedCategory: CategoryWithOptions?
    let onDismiss: () -> Void
    
    init(preselectedCategory: CategoryWithOptions? = nil, onDismiss: @escaping () -> Void = {}) {
        self.preselectedCategory = preselectedCategory
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    
                    if isLoading {
                        loadingView
                    } else if let category = selectedCategory {
                        generationFormView(category: category)
                    } else {
                        errorStateView
                    }
                }
                .pageMargins()
                .padding(.vertical, AppSpacing.sectionSpacing)
            }
            .background(AppColors.backgroundLight)
            .navigationTitle(selectedCategory?.category.name ?? "Create Art")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.primaryBlue)
                }
            }
        }
        .task {
            await loadData()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(error?.localizedDescription ?? "An unknown error occurred")
        }
        .fullScreenCover(isPresented: .constant(generationState.isGenerating)) {
            if case .generating(let generation) = generationState {
                GenerationProgressView(
                    generation: generation,
                    onComplete: { completedGeneration in
                        generationState = .completed(completedGeneration)
                    },
                    onError: { errorMessage in
                        generationState = .failed(errorMessage)
                        error = GenerationError.generationFailed(errorMessage)
                        showingError = true
                    }
                )
            }
        }
        .sheet(isPresented: .constant(generationState.isCompleted)) {
            if case .completed(let generation) = generationState {
                GenerationResultView(
                    generation: generation,
                    onDismiss: {
                        generationState = .idle
                        userPrompt = ""
                    },
                    onGenerateAnother: {
                        generationState = .idle
                    }
                )
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: AppSpacing.xl) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppColors.primaryBlue)
            
            Text("Loading creation options...")
                .font(AppTypography.bodyLarge)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 200)
    }
    
    // MARK: - Generation Form
    @ViewBuilder
    private func generationFormView(category: CategoryWithOptions) -> some View {
        VStack(spacing: AppSpacing.sectionSpacing) {
            
            // Category Header
            categoryHeaderView(category: category.category)
            
            // Style Selection
            styleSelectionView(options: category.options)
            
            // Prompt Input
            promptInputView
            
            // Prompt Enhancement Toggle
            promptEnhancementToggleView
            
            // Generate Button
            generateButtonView
        }
    }
    
    // MARK: - Category Header
    @ViewBuilder
    private func categoryHeaderView(category: GenerationCategory) -> some View {
        VStack(spacing: AppSpacing.md) {
            Text(category.icon)
                .font(.system(size: AppSizing.iconSizes.xxl))
            
            VStack(spacing: AppSpacing.xs) {
                Text(category.name)
                    .headlineLarge()
                    .foregroundColor(AppColors.textPrimary)
                
                Text(category.description)
                    .bodyMedium()
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .cardStyle()
    }
    
    // MARK: - Style Selection
    @ViewBuilder
    private func styleSelectionView(options: [GenerationOption]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Choose Your Style")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
            
            LazyVGrid(columns: GridLayouts.styleGrid, spacing: AppSpacing.grid.itemSpacing) {
                ForEach(options) { option in
                    StyleOptionCard(
                        option: option,
                        isSelected: selectedOption?.id == option.id,
                        categoryColor: categoryColor
                    ) {
                        selectedOption = option
                    }
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Prompt Input
    private var promptInputView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(selectedCategory?.category.id == "coloring_pages" ? "What would you like to color?" : "What would you like to create?")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                TextField("Example: cute cat playing with yarn", text: $userPrompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(AppTypography.bodyLarge)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(AppSpacing.md)
                    .background(AppColors.backgroundLight)
                    .cornerRadius(AppSizing.cornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                            .stroke(AppColors.primaryBlue.opacity(0.3), lineWidth: 1)
                    )
                    .lineLimit(3...6)
                
                Text(selectedCategory?.category.id == "coloring_pages" ? "Describe what you'd like to see in your coloring page" : "Describe what you'd like to create")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .cardStyle()
    }
    
    // MARK: - Prompt Enhancement Toggle
    private var promptEnhancementToggleView: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("AI Prompt Enhancement")
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Let AI improve your prompt for better results")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $promptEnhancementEnabled)
                    .tint(AppColors.primaryBlue)
                    .childSafeTouchTarget()
            }
        }
        .cardStyle()
    }
    
    // MARK: - Generate Button
    private var generateButtonView: some View {
        VStack(spacing: AppSpacing.sm) {
            Button("Create My \(selectedCategory?.category.name ?? "Art")") {
                Task {
                    await generateColoring()
                }
            }
            .largeButtonStyle(backgroundColor: categoryColor)
            .disabled(!canGenerate)
            .childSafeTouchTarget()
            
            if !canGenerate {
                Text("Please select a style and enter a prompt")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Error State
    private var errorStateView: some View {
        VStack(spacing: AppSpacing.xl) {
            Text("😕")
                .font(.system(size: 80))
            
            VStack(spacing: AppSpacing.md) {
                Text("Oops! Something went wrong")
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("We couldn't load the coloring page options. Please try again.")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                
                Button("Try Again") {
                    Task {
                        await loadData()
                    }
                }
                .largeButtonStyle(backgroundColor: AppColors.primaryBlue)
                .childSafeTouchTarget()
            }
        }
        .cardStyle()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 300)
    }
    
    // MARK: - Computed Properties
    private var canGenerate: Bool {
        selectedOption != nil && !userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var categoryColor: Color {
        guard let categoryId = selectedCategory?.category.id else { return AppColors.primaryBlue }
        
        switch categoryId {
        case "coloring_pages":
            return AppColors.coloringPagesColor
        case "stickers":
            return AppColors.stickersColor
        case "wallpapers":
            return AppColors.wallpapersColor
        case "mandalas":
            return AppColors.mandalasColor
        default:
            return AppColors.primaryBlue
        }
    }
    
    // MARK: - Methods
    private func loadData() async {
        isLoading = true
        
        do {
            // Use preselected category if provided, otherwise load from API
            if let preselectedCategory = preselectedCategory {
                selectedCategory = preselectedCategory
                
                // Set default selected option for the preselected category
                if let firstOption = preselectedCategory.options.first(where: { $0.isDefault }) ?? preselectedCategory.options.first {
                    selectedOption = firstOption
                }
            } else {
                // Fallback: load categories and find coloring pages (for backward compatibility)
                let categories = try await generationService.getCategoriesWithOptions()
                selectedCategory = categories.first { $0.category.id == "coloring_pages" }
                
                // Set default selected option
                if let firstOption = selectedCategory?.options.first(where: { $0.isDefault }) ?? selectedCategory?.options.first {
                    selectedOption = firstOption
                }
            }
            
            // Load prompt enhancement setting
            let settings = try await generationService.getPromptEnhancementSettings()
            promptEnhancementEnabled = settings.promptEnhancementEnabled
            
        } catch {
            self.error = error
            showingError = true
        }
        
        isLoading = false
    }
    
    private func generateColoring() async {
        guard let selectedOption = selectedOption,
              let selectedCategory = selectedCategory else { return }
        
        let request = CreateGenerationRequest(
            categoryId: selectedCategory.category.id,
            optionId: selectedOption.id,
            prompt: userPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
            quality: "standard",
            dimensions: "1:1",
            maxImages: 1,
            model: "seedream"
        )
        
        do {
            let generation = try await generationService.createGeneration(request)
            generationState = .generating(generation)
        } catch {
            self.error = error
            showingError = true
        }
    }
}

// MARK: - Supporting Views
struct StyleOptionCard: View {
    let option: GenerationOption
    let isSelected: Bool
    let categoryColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {  // No automatic spacing - we'll control it manually
                // Icon Section - Always starts at same position
                VStack {
                    Circle()
                        .fill(categoryColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text("🎨")
                                .font(.system(size: 20))
                        )
                }
                .frame(height: 60)  // Fixed height for icon section
                
                // Title Section - Always starts at same position
                VStack {
                    Text(option.displayName)
                        .font(AppTypography.titleSmall)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 36)  // Fixed height for title (2 lines max)
                
                // Description Section - Always starts at same position  
                VStack {
                    Text(option.displayDescription)
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 48)  // Fixed height for description (3 lines max)
                
                Spacer()  // Any remaining space goes to bottom
            }
            .padding(AppSpacing.sm)  // Less padding for more content space
            .frame(width: .infinity, height: 160)  // Taller height for better description fit
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                    .fill(isSelected ? categoryColor.opacity(0.1) : AppColors.backgroundLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                            .stroke(
                                isSelected ? categoryColor : AppColors.textSecondary.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .childSafeTouchTarget()
    }
}

// MARK: - Generation State Extensions
extension GenerationState {
    var isGenerating: Bool {
        if case .generating = self {
            return true
        }
        return false
    }
    
    var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }
}