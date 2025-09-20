import SwiftUI

struct GenerationView: View {
    @StateObject private var generationService = GenerationService.shared
    @State private var selectedCategory: CategoryWithOptions?
    @State private var selectedOption: GenerationOption?
    @State private var userPrompt = ""
    @State private var promptEnhancementEnabled = true
    @State private var isUpdatingPromptSetting = false
    @State private var hasLoadedPromptSetting = false

    // Generation options
    @State private var selectedMaxImages = 1
    @State private var selectedQuality = "standard"
    @State private var selectedModel = "seedream"
    @State private var selectedDimensions = "1:1"
    @State private var generationState: GenerationState = .idle
    @State private var isLoading = true
    @State private var error: Error?
    @State private var showingError = false
    @State private var successMessage: String?
    @State private var showingSuccess = false

    let preselectedCategory: CategoryWithOptions?
    let onDismiss: () -> Void

    init(preselectedCategory: CategoryWithOptions? = nil, onDismiss: @escaping () -> Void = {}) {
        #if DEBUG
        print("🎯 GenerationView: init() called")
        print("🎯 GenerationView: preselectedCategory = \(preselectedCategory?.category.name ?? "nil")")
        #endif

        self.preselectedCategory = preselectedCategory
        self.onDismiss = onDismiss

        // Set up the category immediately if preselected
        if let preselectedCategory = preselectedCategory {
            #if DEBUG
            print("🎯 GenerationView: Setting up preselected category in init: \(preselectedCategory.category.name)")
            print("🎯 GenerationView: Options count: \(preselectedCategory.options.count)")
            #endif
            self._selectedCategory = State(initialValue: preselectedCategory)
            self._isLoading = State(initialValue: false)
        } else {
            #if DEBUG
            print("🎯 GenerationView: No preselected category, will load from API")
            #endif
        }
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
                        #if DEBUG
                        print("🔗 GenerationView: User tapped Done, disconnecting SSE and dismissing")
                        #endif
                        GenerationProgressSSEService.shared.disconnect()
                        onDismiss()
                    }
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.primaryBlue)
                }
            }
        }
        .task {
            await loadData()
            await establishSSEConnection()
        }
        .onAppear {
            // Reset success state when view appears
            showingSuccess = false
            successMessage = nil
            hasLoadedPromptSetting = false
        }
        .onDisappear {
            #if DEBUG
            print("🔗 GenerationView: onDisappear called - but NOT disconnecting SSE")
            print("🔗 GenerationView: SSE will disconnect when onDismiss is called or view is truly deallocated")
            #endif
            // Don't disconnect SSE here because fullScreenCover incorrectly triggers onDisappear
            // SSE will be cleaned up via onDismiss callback instead
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(error?.localizedDescription ?? "An unknown error occurred")
        }
        .alert("Success", isPresented: $showingSuccess) {
            Button("OK") { }
        } message: {
            Text(successMessage ?? "Settings updated successfully")
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

            // Generation Options
            maxImagesSelectionView
            qualitySelectionView
            modelSelectionView
            dimensionsSelectionView

            // Generate Button
            generateButtonView
        }
    }

    // MARK: - Category Header
    @ViewBuilder
    private func categoryHeaderView(category: GenerationCategory) -> some View {
        VStack(spacing: AppSpacing.md) {
            Text(category.icon ?? "🎨")
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
        .padding(AppSpacing.cardPadding.inner)
        .background(categoryColor.opacity(0.1))
        .cornerRadius(AppSizing.cornerRadius.md)
        .shadow(
            color: Color.black.opacity(AppSizing.shadows.small.opacity),
            radius: AppSizing.shadows.small.radius,
            x: AppSizing.shadows.small.x,
            y: AppSizing.shadows.small.y
        )
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

                if hasLoadedPromptSetting {
                    Toggle("", isOn: $promptEnhancementEnabled)
                        .tint(AppColors.primaryBlue)
                        .childSafeTouchTarget()
                        .disabled(isUpdatingPromptSetting)
                        .onChange(of: promptEnhancementEnabled) { _, newValue in
                            Task {
                                await updatePromptEnhancementSetting(enabled: newValue)
                            }
                        }
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 51, height: 31) // Same size as Toggle
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Max Images Selection
    private var maxImagesSelectionView: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Number of Images")
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)

                    Text("Choose how many variations to generate")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()
            }

            HStack(spacing: AppSpacing.sm) {
                ForEach(1...4, id: \.self) { count in
                    Button(action: {
                        if count == 1 {
                            selectedMaxImages = count
                        } else {
                            // Show upgrade prompt for free users
                            showUpgradeAlert(feature: "Multiple Images", requiredPlan: "Basic or higher")
                        }
                    }) {
                        Text("\(count)")

                            .font(AppTypography.titleMedium)
                            .foregroundColor(selectedMaxImages == count ? .white : AppColors.textPrimary)
                            .frame(width: 50, height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                    .fill(selectedMaxImages == count ? AppColors.primaryBlue : (count > 1 ? AppColors.textSecondary.opacity(0.1) : AppColors.backgroundLight))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                    .stroke(
                                        selectedMaxImages == count ? AppColors.primaryBlue : (count > 1 ? AppColors.textSecondary.opacity(0.3) : AppColors.textSecondary.opacity(0.2)),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .disabled(count > 1) // Disable for free users
                }

                Spacer()
            }

            if selectedMaxImages > 1 {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(AppColors.primaryBlue)
                    Text("Multiple images available with paid plans")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                    Spacer()
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Quality Selection
    private var qualitySelectionView: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Image Quality")
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)

                    Text("Higher quality takes more time and tokens")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()
            }

            VStack(spacing: AppSpacing.xs) {
                ForEach(["standard", "high", "ultra"], id: \.self) { quality in
                    Button(action: {
                        if quality == "standard" {
                            selectedQuality = quality
                        } else {
                            // Show upgrade prompt for premium quality
                            showUpgradeAlert(feature: "High/Ultra Quality", requiredPlan: "Max or higher")
                        }
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

                            if quality != "standard" {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(AppColors.textSecondary.opacity(0.6))
                                    .font(.system(size: 16))
                            } else if selectedQuality == quality {
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
                                    selectedQuality == quality ? AppColors.primaryBlue : (quality != "standard" ? AppColors.textSecondary.opacity(0.3) : AppColors.textSecondary.opacity(0.2)),
                                    lineWidth: 1
                                )
                        )
                    }
                    .disabled(quality != "standard") // Disable premium options for free users
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

                    Text("Different AI models produce different art styles")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()
            }

            VStack(spacing: AppSpacing.xs) {
                ForEach(["seedream", "flux"], id: \.self) { model in
                    Button(action: {
                        if model == "seedream" {
                            selectedModel = model
                        } else {
                            // Show upgrade prompt for premium models
                            showUpgradeAlert(feature: "Multiple AI Models", requiredPlan: "Business")
                        }
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

                            if model != "seedream" {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(AppColors.textSecondary.opacity(0.6))
                                    .font(.system(size: 16))
                            } else if selectedModel == model {
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
                                    selectedModel == model ? AppColors.primaryBlue : (model != "seedream" ? AppColors.textSecondary.opacity(0.3) : AppColors.textSecondary.opacity(0.2)),
                                    lineWidth: 1
                                )
                        )
                    }
                    .disabled(model != "seedream") // Disable premium models for free users
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
                    Text("Image Dimensions")
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)

                    Text("Choose the aspect ratio for your creation")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()
            }

            HStack(spacing: AppSpacing.sm) {
                ForEach(["1:1", "2:3", "3:2", "A4"], id: \.self) { dimension in
                    Button(action: {
                        selectedDimensions = dimension
                    }) {
                        VStack(spacing: AppSpacing.xxs) {
                            Text(dimension)
                                .font(AppTypography.titleSmall)
                                .foregroundColor(selectedDimensions == dimension ? .white : AppColors.textPrimary)

                            Text(dimensionDescription(dimension))
                                .font(AppTypography.captionSmall)
                                .foregroundColor(selectedDimensions == dimension ? .white.opacity(0.8) : AppColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                .fill(selectedDimensions == dimension ? AppColors.primaryBlue : AppColors.backgroundLight)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                .stroke(
                                    selectedDimensions == dimension ? AppColors.primaryBlue : AppColors.textSecondary.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                    }
                }
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
        guard let category = selectedCategory?.category else { return AppColors.primaryBlue }

        if let colorHex = category.color {
            return Color(hex: colorHex)
        }

        // Fallback to hardcoded colors if backend doesn't provide color
        switch category.id {
        case "coloring_pages": return AppColors.coloringPagesColor
        case "stickers": return AppColors.stickersColor
        case "wallpapers": return AppColors.wallpapersColor
        case "mandalas": return AppColors.mandalasColor
        default: return AppColors.primaryBlue
        }
    }

    // MARK: - Methods
    private func loadData() async {
        #if DEBUG
        print("🎯 GenerationView: loadData() called")
        print("🎯 GenerationView: isLoading = \(isLoading)")
        print("🎯 GenerationView: selectedCategory = \(selectedCategory?.category.name ?? "nil")")
        #endif

        // If we already have a preselected category set in init, just load settings
        if selectedCategory != nil {
            #if DEBUG
            print("🎯 GenerationView: Category already set, just loading settings")
            #endif

            do {
                // Set default selected option if not already set
                if selectedOption == nil, let selectedCategory = selectedCategory {
                    if let firstOption = selectedCategory.options.first(where: { $0.isDefault }) ?? selectedCategory.options.first {
                        selectedOption = firstOption
                        #if DEBUG
                        print("🎯 GenerationView: Default option selected: \(firstOption.name)")
                        #endif
                    }
                }

                // Set default dimensions based on category
                if let selectedCategory = selectedCategory {
                    switch selectedCategory.category.id {
                    case "coloring_pages", "mandalas":
                        selectedDimensions = "2:3" // Portrait for coloring
                    case "stickers":
                        selectedDimensions = "1:1" // Square for stickers
                    case "wallpapers":
                        selectedDimensions = "3:2" // Landscape for wallpapers
                    default:
                        selectedDimensions = "1:1"
                    }
                }

                // Load prompt enhancement setting
                let settings = try await generationService.getPromptEnhancementSettings()
                promptEnhancementEnabled = settings.promptEnhancementEnabled
                hasLoadedPromptSetting = true

            } catch {
                #if DEBUG
                print("❌ GenerationView: Error loading settings: \(error)")
                #endif
                self.error = error
                showingError = true
            }
            return
        }

        isLoading = true

        do {
            // Use preselected category if provided, otherwise load from API
            if let preselectedCategory = preselectedCategory {
                selectedCategory = preselectedCategory

                #if DEBUG
                print("🎯 GenerationView: Setting preselected category: \(preselectedCategory.category.name)")
                print("🎯 GenerationView: Options count: \(preselectedCategory.options.count)")
                for option in preselectedCategory.options {
                    print("   - \(option.name): \(option.description)")
                }
                #endif

                // Set default selected option for the preselected category
                if let firstOption = preselectedCategory.options.first(where: { $0.isDefault }) ?? preselectedCategory.options.first {
                    selectedOption = firstOption
                    #if DEBUG
                    print("🎯 GenerationView: Default option selected: \(firstOption.name)")
                    #endif
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
            hasLoadedPromptSetting = true

        } catch {
            #if DEBUG
            print("❌ GenerationView: Error loading data: \(error)")
            #endif
            self.error = error
            showingError = true
        }

        isLoading = false
        #if DEBUG
        print("🎯 GenerationView: Loading complete. isLoading = false")
        #endif
    }

    // MARK: - Helper Methods
    private func qualityDescription(_ quality: String) -> String {
        switch quality {
        case "standard": return "Fast generation, good quality"
        case "high": return "Better quality, slower generation"
        case "ultra": return "Best quality, longest generation time"
        default: return ""
        }
    }

    private func modelDescription(_ model: String) -> String {
        switch model {
        case "seedream": return "Fast, family-friendly AI model"
        case "flux": return "Advanced model with more detail"
        default: return ""
        }
    }

    private func dimensionDescription(_ dimension: String) -> String {
        switch dimension {
        case "1:1": return "Square"
        case "2:3": return "Portrait"
        case "3:2": return "Landscape"
        case "A4": return "Paper"
        default: return ""
        }
    }

    private func showUpgradeAlert(feature: String, requiredPlan: String) {
        // TODO: Show upgrade alert
        #if DEBUG
        print("🔒 Upgrade required: \(feature) needs \(requiredPlan)")
        #endif

        // For now, show in error alert system
        error = GenerationError.upgradeRequired(feature: feature, plan: requiredPlan)
        showingError = true
    }

    private func updatePromptEnhancementSetting(enabled: Bool) async {
        await MainActor.run {
            isUpdatingPromptSetting = true
        }

        do {
            let result = try await generationService.updatePromptEnhancementSettings(enabled: enabled)
            #if DEBUG
            print("🎯 GenerationView: Prompt enhancement updated to: \(result.settings.promptEnhancementEnabled)")
            #endif
            await MainActor.run {
                isUpdatingPromptSetting = false
                successMessage = result.message
                showingSuccess = true
            }
        } catch {
            #if DEBUG
            print("❌ GenerationView: Failed to update prompt enhancement setting: \(error)")
            #endif
            // Revert the toggle state on error
            await MainActor.run {
                promptEnhancementEnabled = !enabled
                isUpdatingPromptSetting = false
            }
            self.error = error
            showingError = true
        }
    }

    private func generateColoring() async {
        guard let selectedOption = selectedOption,
              let selectedCategory = selectedCategory else { return }

        let request = CreateGenerationRequest(
            categoryId: selectedCategory.category.id,
            optionId: selectedOption.id,
            prompt: userPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
            quality: selectedQuality,
            dimensions: selectedDimensions,
            maxImages: selectedMaxImages,
            model: selectedModel,
            familyProfileId: nil  // TODO: Add family profile support later
        )

        do {
            #if DEBUG
            print("🔗 GenerationView: Creating generation, SSE connection status: \(GenerationProgressSSEService.shared.isConnected)")
            #endif

            let generation = try await generationService.createGeneration(request)

            #if DEBUG
            print("🎯 GenerationView: Created generation with ID: \(generation.id)")
            #endif

            // Start tracking this specific generation (resets progress to 0% to prevent UI flash)
            GenerationProgressSSEService.shared.startTrackingGeneration(generation.id)

            generationState = .generating(generation)
        } catch {
            self.error = error
            showingError = true
        }
    }
    
    // MARK: - SSE Connection Management
    private func establishSSEConnection() async {
        guard let token = try? KeychainManager.shared.retrieveToken() else {
            #if DEBUG
            print("🔗 GenerationView: No auth token available for SSE connection")
            #endif
            return
        }
        
        #if DEBUG
        print("🔗 GenerationView: Establishing SSE connection for GenerationView session")
        print("🔗 GenerationView: Current connection status: \(GenerationProgressSSEService.shared.isConnected)")
        #endif
        
        // Establish connection if not already connected
        GenerationProgressSSEService.shared.connectToUserProgress(authToken: token)
        
        // Wait for connection to establish
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        #if DEBUG
        print("🔗 GenerationView: SSE connection established: \(GenerationProgressSSEService.shared.isConnected)")
        #endif
    }
}

// MARK: - Supporting Views
struct StyleOptionCard: View {
    let option: GenerationOption
    let isSelected: Bool
    let categoryColor: Color
    let action: () -> Void

    private var optionColor: Color {
        if let colorHex = option.color {
            return Color(hex: colorHex)
        }
        return categoryColor
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {  // No automatic spacing - we'll control it manually
                // Icon/Image Section - Always starts at same position
                VStack {
                    if let imageUrl = option.imageUrl, let url = URL(string: imageUrl) {
                        // Use backend image
                        AsyncImage(url: url) { imagePhase in
                            switch imagePhase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 44, height: 44)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(optionColor.opacity(0.4), lineWidth: 1)
                                    )
                            case .failure(_), .empty:
                                // Fallback to colored circle
                                Circle()
                                    .fill(optionColor.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Text("🎨")
                                            .font(.system(size: 20))
                                    )
                            @unknown default:
                                Circle()
                                    .fill(optionColor.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Text("🎨")
                                            .font(.system(size: 20))
                                    )
                            }
                        }
                    } else {
                        // Fallback to colored circle
                        Circle()
                            .fill(optionColor.opacity(0.2))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text("🎨")
                                    .font(.system(size: 20))
                            )
                    }
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
            .frame(height: 160)  // Taller height for better description fit
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                    .fill(isSelected ? optionColor.opacity(0.2) : optionColor.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                            .stroke(
                                isSelected ? optionColor : AppColors.textSecondary.opacity(0.2),
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