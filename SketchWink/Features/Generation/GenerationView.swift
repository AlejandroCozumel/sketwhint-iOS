import SwiftUI

// MARK: - Input Method Enum
enum InputMethod: String, CaseIterable {
    case text = "text"
    case image = "image"
    
    var displayName: String {
        switch self {
        case .text: return "generation.enter.prompt".localized
        case .image: return "generation.upload.photo".localized
        }
    }

    var icon: String {
        switch self {
        case .text: return "pencil.and.outline"
        case .image: return "camera.fill"
        }
    }

    var description: String {
        switch self {
        case .text: return "generation.prompt.placeholder".localized
        case .image: return "generation.convert.photo.desc".localized
        }
    }
}

struct GenerationView: View {
    @StateObject private var generationService = GenerationService.shared
    @StateObject private var localization = LocalizationManager.shared
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
    @State private var userPermissions: UserPermissions?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var showingError = false
    @State private var showingSubscriptionPlans = false
    @State private var highlightedFeature: String?
    @State private var successMessage: String?
    @State private var showingSuccess = false

    // Image Upload State
    @State private var selectedInputImage: UIImage?
    @State private var inputMethod: InputMethod = .text
    @State private var showingPhotoSourceSelection = false
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingImagePreview = false
    @State private var currentStep = 1
    @State private var transitionEdge: Edge = .trailing

    @FocusState private var isPromptFocused: Bool

    let preselectedCategory: CategoryWithOptions?
    let onDismiss: () -> Void
    @Binding var selectedTab: Int

    init(preselectedCategory: CategoryWithOptions? = nil, selectedTab: Binding<Int>, onDismiss: @escaping () -> Void = {}) {
        self._selectedTab = selectedTab
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
        mainContent
            .task {
                await loadData()
                await establishSSEConnection()
            }
            .onAppear(perform: handleOnAppear)
            .onDisappear(perform: handleOnDisappear)
            .alert("common.error".localized, isPresented: $showingError) {
                Button("common.ok".localized) { }
            } message: {
                Text(error?.localizedDescription ?? "common.unknown.error".localized)
            }
            .alert("common.success".localized, isPresented: $showingSuccess) {
                Button("common.ok".localized) { }
            } message: {
                Text(successMessage ?? "common.success".localized)
            }
            .dismissableFullScreenCover(isPresented: .constant(generationState.isGenerating)) {
                progressCover
            }
            .sheet(isPresented: resultSheetBinding) {
                resultSheet
            }
            .sheet(isPresented: $showingPhotoSourceSelection) {
                PhotoSourceSelectionView(
                    showingImagePicker: $showingImagePicker,
                    showingCamera: $showingCamera,
                    selectedImage: $selectedInputImage
                )
            }
            .sheet(isPresented: $showingImagePreview) {
                if let selectedImage = selectedInputImage,
                   let selectedCategory = selectedCategory,
                   let selectedOption = selectedOption {
                    ImagePreviewView(
                        selectedImage: selectedImage,
                        selectedCategory: selectedCategory,
                        selectedOption: selectedOption,
                        onConfirm: { confirmedImage in
                            selectedInputImage = confirmedImage
                        }
                    )
                }
            }
            .onChange(of: selectedInputImage) { oldValue, newValue in
                if newValue != nil {
                    showingPhotoSourceSelection = false
                }
            }
            .onChange(of: selectedOption?.id) { _, newValue in
                if newValue == nil && currentStep > 1 {
                    transitionEdge = .leading
                    withAnimation(.easeInOut) {
                        currentStep = 1
                    }
                }
            }
    }

    // MARK: - View Components

    private var mainContent: some View {
        NavigationView {
            VStack(spacing: 0) {
                progressBar
                stepContent
            }
                .navigationTitle(navigationTitleText)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if currentStep > 1 {
                            Button(action: {
                                transitionEdge = .leading
                                withAnimation(.easeInOut) {
                                    currentStep -= 1
                                }
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(AppColors.surfaceLight)
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(AppColors.primaryBlue)
                                }
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(AppColors.borderLight, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("generation.back".localized)
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        doneButton
                    }
                }
                .toolbarBackground(AppColors.backgroundLight, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
        .background(AppColors.backgroundLight)
        .cornerRadius(20)
        .ignoresSafeArea(edges: .bottom)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private var progressBar: some View {
        VStack(spacing: AppSpacing.xs) {
            HStack(spacing: 4) {
                ForEach(1...2, id: \.self) { step in
                    Rectangle()
                        .fill(step <= currentStep ? AppColors.primaryBlue : AppColors.borderLight)
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)
                }
            }

            Text(String(format: "generation.step.of".localized, currentStep))
                .font(AppTypography.captionLarge)
                .foregroundColor(AppColors.textSecondary)
                .padding(.top, 4)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.sm)
        .background(AppColors.backgroundLight)
    }

    private var stepContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    if isLoading {
                        loadingView
                    } else if let category = selectedCategory {
                        switch currentStep {
                        case 1:
                            stepOneStyleSelection(category: category)
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: transitionEdge),
                                        removal: .move(edge: transitionEdge == .trailing ? .leading : .trailing)
                                    )
                                )
                                .id("step1")
                        case 2:
                            generationFormView(category: category)
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: transitionEdge),
                                        removal: .move(edge: transitionEdge == .trailing ? .leading : .trailing)
                                    )
                                )
                                .id("step2")
                        default:
                            EmptyView()
                        }
                    } else {
                        errorStateView
                    }
                }
                .pageMargins()
                .padding(.top, AppSpacing.sectionSpacing)
                .padding(.bottom, currentStep == 1 ? AppSpacing.md : AppSpacing.sectionSpacing)
            }
            .dismissKeyboardOnScroll()
            .simultaneousGesture(
                DragGesture().onChanged { _ in
                    // Dismiss keyboard when user starts scrolling
                    isPromptFocused = false
                }
            )
            .onChange(of: currentStep) { _, newValue in
                withAnimation(.easeInOut) {
                    proxy.scrollTo("step\(newValue)", anchor: .top)
                }
            }
            .animation(.easeInOut, value: currentStep)
            .background(AppColors.backgroundLight)
        }
    }

    private var doneButton: some View {
        Button(action: {
            #if DEBUG
            print("🔗 GenerationView: User tapped Done, disconnecting SSE and dismissing")
            #endif
            GenerationProgressSSEService.shared.disconnect()
            currentStep = 1
            onDismiss()
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppColors.textSecondary)
                .padding(8)
                .background(AppColors.surfaceLight)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(AppColors.borderLight, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("generation.close".localized)
    }

    @ViewBuilder
    private var progressCover: some View {
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
                    userPrompt = ""
                    selectedInputImage = nil
                },
                onCancel: {
                    generationState = .idle
                }
            )
        }
    }

    private var resultSheetBinding: Binding<Bool> {
        Binding(
            get: {
                if case .completed = generationState {
                    return true
                }
                return false
            },
            set: { presented in
                if !presented {
                    generationState = .idle
                    userPrompt = ""
                    selectedInputImage = nil
                    isPromptFocused = false
                    currentStep = 1
                }
            }
        )
    }

    @ViewBuilder
    private var resultSheet: some View {
        if case .completed(let generation) = generationState {
            GenerationResultView(
                generation: generation,
                selectedTab: $selectedTab,
                onDismiss: {
                    generationState = .idle
                    userPrompt = ""
                    selectedInputImage = nil
                    isPromptFocused = false
                    currentStep = 1
                },
                onGenerateAnother: {
                    generationState = .idle
                    userPrompt = ""
                    selectedInputImage = nil
                    isPromptFocused = false
                    currentStep = 1
                },
                onDismissParent: {
                    // Dismiss the parent GenerationView sheet
                    GenerationProgressSSEService.shared.disconnect()
                    currentStep = 1
                    onDismiss()
                }
            )
        }
    }

    // MARK: - Lifecycle Methods

    private func handleOnAppear() {
        showingSuccess = false
        successMessage = nil
        hasLoadedPromptSetting = false
        currentStep = 1
    }

    private func handleOnDisappear() {
        #if DEBUG
        print("🔗 GenerationView: onDisappear called - but NOT disconnecting SSE")
        print("🔗 GenerationView: SSE will disconnect when onDismiss is called or view is truly deallocated")
        #endif
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: AppSpacing.xl) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppColors.primaryBlue)

            Text("generation.loading.options".localized)
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
            // Input Method Selection
            self.inputMethodSelectionView

            // Prompt Input (conditionally shown based on input method)
            if self.inputMethod == .text {
                promptInputView
                
                // Prompt Enhancement Toggle (only show for text input)
                promptEnhancementToggleView
            } else if self.inputMethod == .image {
                self.imageInputView
            }

            // Generation Options
            maxImagesSelectionView
            qualitySelectionView
            modelSelectionView
            dimensionsSelectionView

            // Generate Button
            generateButtonView
        }
    }

    // MARK: - Step One Style Selection
    @ViewBuilder
    private func stepOneStyleSelection(category: CategoryWithOptions) -> some View {
        VStack(spacing: AppSpacing.sectionSpacing) {
            styleSelectionView(options: category.options)

            Text("generation.pick.style".localized)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, AppSpacing.sm)
        }
    }

    // MARK: - Style Selection
    @ViewBuilder
    private func styleSelectionView(options: [GenerationOption]) -> some View {
        VStack(alignment: .center, spacing: AppSpacing.md) {
            Text("generation.choose.style".localized)
                .font(AppTypography.categoryTitle)
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 10)

            LazyVGrid(columns: GridLayouts.styleGrid, spacing: AppSpacing.grid.itemSpacing) {
                ForEach(options) { option in
                    StyleOptionCard(
                        option: option,
                        isSelected: selectedOption?.id == option.id,
                        categoryColor: categoryColor
                    ) {
                        handleStyleSelection(option)
                    }
                }
            }
        }
    }

    private func handleStyleSelection(_ option: GenerationOption) {
        selectedOption = option

        if currentStep == 1 {
            transitionEdge = .trailing
            withAnimation(.easeInOut) {
                currentStep = 2
            }
        }
    }

    private var navigationTitleText: String {
        if currentStep == 2, let selectedOption {
            return selectedOption.name
        }
        return selectedCategory?.category.name ?? "generation.title".localized
    }

    // MARK: - Prompt Input
    private var promptInputView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(selectedCategory?.category.id == "coloring_pages" ? "generation.what.to.color".localized : "generation.what.to.create".localized)
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                TextField("generation.example.prompt".localized, text: $userPrompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(AppTypography.bodyLarge)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(AppSpacing.md)
                    .background(AppColors.backgroundLight)
                    .cornerRadius(AppSizing.cornerRadius.md)
                    .focused($isPromptFocused)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                            .stroke(
                                isPromptFocused ? AppColors.primaryBlue : AppColors.borderLight,
                                lineWidth: isPromptFocused ? 2 : 1
                            )
                    )
                    .lineLimit(3...6)

                Text(selectedCategory?.category.id == "coloring_pages" ? "generation.describe.coloring".localized : "generation.describe.creation".localized)
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
                    Text("generation.ai.enhancement".localized)
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)

                    Text("generation.ai.enhancement.desc".localized)
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
                    Text("generation.number.of.images".localized)
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)

                    Text("generation.image.count.desc".localized)
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()
            }

            HStack(spacing: AppSpacing.sm) {
                ForEach(1...4, id: \.self) { count in
                    let isAvailable = count <= (userPermissions?.maxImagesPerGeneration ?? 1)
                    let isSelected = selectedMaxImages == count
                    
                    Button(action: {
                        #if DEBUG
                        print("🔘 Image count \(count) tapped")
                        print("🔘 isAvailable: \(isAvailable)")
                        print("🔘 userPermissions?.maxImagesPerGeneration: \(userPermissions?.maxImagesPerGeneration ?? -1)")
                        print("🔘 showingSubscriptionPlans before: \(showingSubscriptionPlans)")
                        #endif
                        
                        if isAvailable {
                            selectedMaxImages = count
                            #if DEBUG
                            print("🔘 Selected max images: \(count)")
                            #endif
                        } else {
                            // Navigate to subscription plans for restricted users
                            highlightedFeature = "Multiple Images"
                            showingSubscriptionPlans = true
                            #if DEBUG
                            print("🔘 Navigating to subscription plans")
                            print("🔘 highlightedFeature: \(highlightedFeature ?? "nil")")
                            print("🔘 showingSubscriptionPlans after: \(showingSubscriptionPlans)")
                            #endif
                        }
                    }) {
                        HStack(spacing: AppSpacing.xs) {
                            Text("\(count)")
                                .font(AppTypography.titleMedium)
                                .foregroundColor(isSelected ? .white : (isAvailable ? AppColors.textPrimary : AppColors.textSecondary))
                            
                            if !isAvailable {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary.opacity(0.6))
                            } else if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 60, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                .fill(isSelected ? AppColors.primaryBlue : (isAvailable ? AppColors.backgroundLight : AppColors.textSecondary.opacity(0.1)))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                .stroke(
                                    isSelected ? AppColors.primaryBlue : (isAvailable ? AppColors.textSecondary.opacity(0.2) : AppColors.textSecondary.opacity(0.3)),
                                    lineWidth: 1
                                )
                        )
                    }
                    .childSafeTouchTarget()
                }

                Spacer()
            }

            // Show info for current plan limits
            if let permissions = userPermissions {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(AppColors.primaryBlue)
                    Text(String(format: "generation.plan.allows.images".localized, permissions.planName, permissions.maxImagesPerGeneration, permissions.maxImagesPerGeneration == 1 ? "" : "es"))
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
                    Text("generation.image.quality".localized)
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)

                    Text("generation.quality.desc".localized)
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()
            }

            VStack(spacing: AppSpacing.xs) {
                ForEach(["standard", "high", "ultra"], id: \.self) { quality in
                    let isAvailable = userPermissions?.availableQuality.contains(quality) ?? (quality == "standard")
                    
                    Button(action: {
                        #if DEBUG
                        print("🔘 Quality \(quality) tapped")
                        print("🔘 isAvailable: \(isAvailable)")
                        print("🔘 userPermissions?.availableQuality: \(userPermissions?.availableQuality ?? [])")
                        #endif
                        
                        if isAvailable {
                            selectedQuality = quality
                            #if DEBUG
                            print("🔘 Selected quality: \(quality)")
                            #endif
                        } else {
                            // Navigate to subscription plans for premium quality
                            highlightedFeature = "High/Ultra Quality"
                            showingSubscriptionPlans = true
                            #if DEBUG
                            print("🔘 Navigating to subscription plans for quality")
                            print("🔘 showingSubscriptionPlans: \(showingSubscriptionPlans)")
                            #endif
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

                            if !isAvailable {
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
                                    selectedQuality == quality ? AppColors.primaryBlue : (isAvailable ? AppColors.textSecondary.opacity(0.2) : AppColors.textSecondary.opacity(0.3)),
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
                    Text("generation.ai.model".localized)
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)

                    Text("generation.model.desc".localized)
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()
            }

            VStack(spacing: AppSpacing.xs) {
                ForEach(["seedream", "gemini", "flux"], id: \.self) { model in
                    let isAvailable = userPermissions?.availableModels.contains(model) ?? (model == "seedream" || model == "gemini")

                    Button(action: {
                        if isAvailable {
                            selectedModel = model
                        } else {
                            // Navigate to subscription plans for premium models
                            highlightedFeature = "Multiple AI Models"
                            showingSubscriptionPlans = true
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

                            if !isAvailable {
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
                                    selectedModel == model ? AppColors.primaryBlue : (isAvailable ? AppColors.textSecondary.opacity(0.2) : AppColors.textSecondary.opacity(0.3)),
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
                    Text("generation.image.dimensions".localized)
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)

                    Text("generation.dimensions.desc".localized)
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
            Button {
                Task {
                    await generateColoring()
                }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    if case .loading = generationState {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.9)
                    }

                    Text(generationState == .loading ? "generation.creating.art".localized : String(format: "generation.create.my.art".localized, selectedCategory?.category.name ?? ""))
                }
                .largeButtonStyle(
                    backgroundColor: categoryColor,
                    isDisabled: !canGenerate || generationState == .loading
                )
            }
            .disabled(!canGenerate || generationState == .loading)

            if !canGenerate {
                Text(generateButtonValidationText)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.errorRed)
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
                Text("generation.error.title".localized)
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)

                Text("generation.error.message".localized)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)

                Button("generation.try.again".localized) {
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
        guard selectedOption != nil else { return false }
        
        switch self.inputMethod {
        case .text:
            return !userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .image:
            return selectedInputImage != nil
        }
    }
    
    private var generateButtonValidationText: String {
        if selectedOption == nil {
            return "generation.select.style.error".localized
        }

        switch self.inputMethod {
        case .text:
            return "generation.enter.prompt.error".localized
        case .image:
            return "generation.select.photo.error".localized
        }
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

                // Load prompt enhancement setting and user permissions
                let settings = try await generationService.getPromptEnhancementSettings()
                promptEnhancementEnabled = settings.promptEnhancementEnabled
                hasLoadedPromptSetting = true
                
                // Load user permissions
                userPermissions = try await generationService.getUserPermissions()
                
                #if DEBUG
                if let permissions = userPermissions {
                    print("🔒 User Permissions Loaded:")
                    print("   - Plan: \(permissions.planName)")
                    print("   - Max Images: \(permissions.maxImagesPerGeneration)")
                    print("   - Quality Options: \(permissions.availableQuality)")
                    print("   - Model Options: \(permissions.availableModels)")
                }
                #endif

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

            } else {
                // Fallback: load categories and find coloring pages (for backward compatibility)
                let categories = try await generationService.getCategoriesWithOptions()
                selectedCategory = categories.first { $0.category.id == "coloring_pages" }

            }

            // Load prompt enhancement setting and user permissions
            let settings = try await generationService.getPromptEnhancementSettings()
            promptEnhancementEnabled = settings.promptEnhancementEnabled
            hasLoadedPromptSetting = true
            
            // Load user permissions
            userPermissions = try await generationService.getUserPermissions()
            
            #if DEBUG
            if let permissions = userPermissions {
                print("🔒 User Permissions Loaded:")
                print("   - Plan: \(permissions.planName)")
                print("   - Max Images: \(permissions.maxImagesPerGeneration)")
                print("   - Quality Options: \(permissions.availableQuality)")
                print("   - Model Options: \(permissions.availableModels)")
            }
            #endif

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
        case "standard": return "generation.quality.standard.desc".localized
        case "high": return "generation.quality.high.desc".localized
        case "ultra": return "generation.quality.ultra.desc".localized
        default: return ""
        }
    }

    private func modelDescription(_ model: String) -> String {
        switch model {
        case "seedream": return "generation.model.seedream.desc".localized
        case "gemini": return "generation.model.gemini.desc".localized
        case "flux": return "generation.model.flux.desc".localized
        default: return ""
        }
    }

    private func dimensionDescription(_ dimension: String) -> String {
        switch dimension {
        case "1:1": return "generation.dimensions.square".localized
        case "2:3": return "generation.dimensions.portrait".localized
        case "3:2": return "generation.dimensions.landscape".localized
        case "A4": return "generation.dimensions.paper".localized
        default: return ""
        }
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
        // Prevent double-click - only proceed if idle
        guard case .idle = generationState else {
            return
        }

        guard let selectedOption = selectedOption,
              let selectedCategory = selectedCategory else { return }

        // Validate input first
        guard validateImageInput() else { return }

        // Set loading state
        generationState = .loading

        // Create request based on input method
        let request: CreateGenerationRequest

        #if DEBUG
        print("🎯 GenerationView: Creating generation request with:")
        print("   - selectedMaxImages: \(selectedMaxImages)")
        print("   - selectedQuality: \(selectedQuality)")
        print("   - selectedModel: \(selectedModel)")
        print("   - selectedDimensions: \(selectedDimensions)")
        #endif

        if self.inputMethod == .image, let inputImage = selectedInputImage {
            // Image-based generation
            request = CreateGenerationRequest(
                categoryId: selectedCategory.category.id,
                optionId: selectedOption.id,
                prompt: userPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
                inputImage: inputImage,  // This will be processed and converted to base64
                quality: selectedQuality,
                dimensions: selectedDimensions,
                maxImages: selectedMaxImages,
                model: selectedModel,
                familyProfileId: nil  // TODO: Add family profile support later
            )

            #if DEBUG
            print("📷 GenerationView: Creating image-based generation")
            print("📐 GenerationView: Image size: \(inputImage.size)")
            #endif
        } else {
            // Text-based generation
            request = CreateGenerationRequest(
                categoryId: selectedCategory.category.id,
                optionId: selectedOption.id,
                prompt: userPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
                quality: selectedQuality,
                dimensions: selectedDimensions,
                maxImages: selectedMaxImages,
                model: selectedModel,
                familyProfileId: nil  // TODO: Add family profile support later
            )

            #if DEBUG
            print("✏️ GenerationView: Creating text-based generation")
            print("📝 GenerationView: Prompt: \(userPrompt)")
            #endif
        }

        #if DEBUG
        print("📦 GenerationView: Request created with maxImages: \(request.maxImages ?? -1)")
        #endif

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
            // Reset to idle state on error so button becomes enabled again
            generationState = .idle
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
    
    // MARK: - Input Method Selection
    private var inputMethodSelectionView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("generation.how.to.create".localized)
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
            
            HStack(alignment: .top, spacing: AppSpacing.md) {
                ForEach(InputMethod.allCases, id: \.rawValue) { method in
                    Button(action: {
                        handleInputMethodSelection(method)
                    }) {
                        VStack(spacing: AppSpacing.sm) {
                            Image(systemName: method.icon)
                                .font(.system(size: 24))
                                .foregroundColor(self.inputMethod == method ? .white : AppColors.primaryBlue)
                                .frame(height: 24)

                            VStack(spacing: 4) {
                                Text(method.displayName)
                                    .titleMedium()
                                    .foregroundColor(self.inputMethod == method ? .white : AppColors.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .frame(maxWidth: .infinity, minHeight: 50, alignment: .top)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(method.description)
                                    .captionLarge()
                                    .foregroundColor(self.inputMethod == method ? .white.opacity(0.9) : AppColors.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .top)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, AppSpacing.md)
                        .padding(.horizontal, AppSpacing.sm)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(self.inputMethod == method ? AppColors.primaryBlue : AppColors.backgroundLight)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            self.inputMethod == method ? AppColors.primaryBlue : AppColors.borderLight,
                                            lineWidth: self.inputMethod == method ? 2 : 1
                                        )
                                )
                        )
                    }
                    .childSafeTouchTarget()
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }
    
    // MARK: - Image Input View
    private var imageInputView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("generation.photo.for.coloring".localized)
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
            
            if let selectedImage = selectedInputImage {
                // Show selected image - Full width with proper aspect ratio
                Button(action: {
                    showingPhotoSourceSelection = true
                }) {
                    ZStack {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .cornerRadius(12)
                        
                        // Absolute positioned buttons inside the photo
                        VStack {
                            HStack {
                                Spacer()
                                
                                // Remove button (top-right) - Double size
                                Button(action: {
                                    selectedInputImage = nil
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.6), in: Circle())
                                }
                                .childSafeTouchTarget()
                            }
                            
                            Spacer()
                            Spacer()
                            
                            HStack {
                                // Change photo button (bottom-left) - Lower position
                                Button(action: {
                                    showingPhotoSourceSelection = true
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 12))
                                        Text("generation.change.photo".localized)
                                            .font(AppTypography.captionLarge)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.6), in: Capsule())
                                }
                                .childSafeTouchTarget()
                                
                                Spacer()
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .padding(.horizontal, 8)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Show upload button
                Button(action: {
                    handleImageUploadTap()
                }) {
                    VStack(spacing: AppSpacing.md) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundColor(AppColors.primaryBlue)
                        
                        VStack(spacing: AppSpacing.xs) {
                            Text("generation.add.photo".localized)
                                .titleMedium()
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("generation.tap.to.select".localized)
                                .captionLarge()
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 140)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.primaryBlue.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    )
                }
                .childSafeTouchTarget()
            }
            
            // Add description text field for image context
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                TextField("generation.optional.describe.photo".localized, text: $userPrompt, axis: .vertical)
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
                    .lineLimit(2...4)

                Text("generation.help.ai.photo".localized)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .cardStyle()
    }
    
    // MARK: - Input Method Handling
    private func handleInputMethodSelection(_ method: InputMethod) {
        self.inputMethod = method

        // Don't clear data when switching - preserve user's work
        // The API will use the appropriate field based on input method

        // Auto-show photo selection for image method
        if method == .image && selectedInputImage == nil {
            handleImageUploadTap()
        }
    }
    
    private func handleImageUploadTap() {
        // Check subscription permissions first
        guard let permissions = userPermissions else { return }
        
        if !permissions.hasImageUpload {
            // Show upgrade prompt for free users
            highlightedFeature = "image_upload"
            showingSubscriptionPlans = true
            return
        }
        
        showingPhotoSourceSelection = true
    }
    
    // MARK: - Image Processing
    private func processImageForGeneration(_ image: UIImage) -> Result<UIImage, ImageProcessingError> {
        return image.safeProcessForUpload(maxSize: 1024, quality: 0.7, maxFileSize: 2_097_152)
    }
    
    private func validateImageInput() -> Bool {
        guard self.inputMethod == .image else { return true }
        
        guard let image = selectedInputImage else {
            error = ImageProcessingError.invalidFormat
            showingError = true
            return false
        }
        
        // Process image first (resize + compress), THEN validate
        let processedImage = image.processForUpload(maxSize: 1024, quality: 0.7)
        let validation = processedImage.validateForUpload(maxSize: 1024, maxFileSize: 2_097_152, quality: 0.7)
        if !validation.isValid {
            if let reason = validation.reason {
                error = NSError(domain: "ImageValidation", code: 0, userInfo: [NSLocalizedDescriptionKey: reason])
                showingError = true
            }
            return false
        }
        
        // Replace original image with processed image to prevent double processing
        selectedInputImage = processedImage
        
        return true
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
            VStack(spacing: 0) {
                // Top half - Image (no padding, rounded top corners only)
                if let imageUrl = option.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { imagePhase in
                        switch imagePhase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .frame(height: 200, alignment: .top)
                                .clipped()
                        case .failure(_):
                            Rectangle()
                                .fill(optionColor.opacity(0.2))
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .frame(height: 200)
                                .overlay(
                                    Text("🎨")
                                        .font(.system(size: 40))
                                )
                        case .empty:
                            // Skeleton loading state
                            Rectangle()
                                .fill(AppColors.textSecondary.opacity(0.3))
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .frame(height: 200)
                                .shimmer()
                        @unknown default:
                            Rectangle()
                                .fill(optionColor.opacity(0.2))
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .frame(height: 200)
                                .overlay(
                                    Text("🎨")
                                        .font(.system(size: 40))
                                )
                        }
                    }
                } else {
                    Rectangle()
                        .fill(optionColor.opacity(0.2))
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .frame(height: 200)
                        .overlay(
                            Text("🎨")
                                .font(.system(size: 40))
                        )
                }

                // Bottom half - Text with padding
                VStack(spacing: AppSpacing.xs) {
                    Text(option.displayName)
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(option.displayDescription)
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity)
                .frame(height: 100)
            }
            .frame(height: 300)
            .frame(minWidth: 0, maxWidth: .infinity)
            .background(isSelected ? optionColor.opacity(0.15) : optionColor.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                    .stroke(isSelected ? AppColors.primaryBlue : optionColor.opacity(0.3), lineWidth: isSelected ? 3 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg))
            .shadow(
                color: optionColor.opacity(0.3),
                radius: 10,
                x: 0,
                y: 10
            )
        }
        .childSafeTouchTarget()
    }
}

// MARK: - Image Processing Error Extension
extension ImageProcessingError {
    var userFriendlyMessage: String {
        switch self {
        case .conversionFailed:
            return "generation.photo.process.error".localized
        case .compressionFailed:
            return "generation.photo.compress.error".localized
        case .invalidFormat:
            return "generation.photo.invalid".localized
        case .fileTooLarge(let currentSize, let maxSize):
            let currentMB = Double(currentSize) / 1_048_576
            let maxMB = Double(maxSize) / 1_048_576
            return String(format: "generation.photo.too.large.mb".localized, currentMB, maxMB)
        case .dimensionsTooLarge(let currentDimensions, let maxSize):
            return String(format: "generation.photo.too.large.px".localized, Int(currentDimensions.width), Int(currentDimensions.height), Int(maxSize), Int(maxSize))
        }
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
