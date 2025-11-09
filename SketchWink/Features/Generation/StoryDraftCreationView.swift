import SwiftUI

// MARK: - Draft Creation State
enum DraftCreationState {
    case idle
    case creating
    case completed(StoryDraft)
    case failed(String)
    
    var isCreating: Bool {
        if case .creating = self { return true }
        return false
    }
    
    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }
}

struct StoryDraftCreationView: View {
    @StateObject private var draftService = DraftService.shared
    @State private var currentStep = 1
    @State private var selectedStoryType: StoryType?
    @State private var selectedAgeGroup: AgeGroup = .preschool
    @State private var userTheme = ""
    @State private var selectedPageCount = 4
    @State private var selectedFocusTag: FocusTag = .magicImagination
    @State private var customFocus = ""
    @State private var draftCreationState: DraftCreationState = .idle
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showingError = false
    @State private var isShowingProgress = false
    @State private var showingPreview = false
    @State private var activeDraft: StoryDraft?
    @State private var transitionEdge: Edge = .trailing
    @State private var showingGenerationAlert = false
    @State private var isGeneratingBook = false
    
    let productCategory: ProductCategory
    let onDismiss: () -> Void
    let onDraftCreated: (StoryDraft) -> Void
    
    
    
    init(productCategory: ProductCategory, onDismiss: @escaping () -> Void = {}, onDraftCreated: @escaping (StoryDraft) -> Void) {
        self.productCategory = productCategory
        self.onDismiss = onDismiss
        self.onDraftCreated = onDraftCreated
        
        #if DEBUG
        print("📝 StoryDraftCreationView: init() called for \(productCategory.name)")
        #endif
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                progressBar

                // Main content
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        if isLoading {
                            loadingView
                        } else {
                            switch currentStep {
                            case 1:
                                step1StoryTypeSelection
                                    .transition(.asymmetric(insertion: .move(edge: transitionEdge), removal: .move(edge: transitionEdge == .trailing ? .leading : .trailing)))
                            case 2:
                                step2StoryDetails
                                    .transition(.asymmetric(insertion: .move(edge: transitionEdge), removal: .move(edge: transitionEdge == .trailing ? .leading : .trailing)))
                            case 3:
                                step3DraftPreview
                                    .transition(.asymmetric(insertion: .move(edge: transitionEdge), removal: .move(edge: transitionEdge == .trailing ? .leading : .trailing)))
                            default:
                                EmptyView()
                            }
                        }
                    }
                    .padding(AppSpacing.md)
                    .padding(.bottom, AppSpacing.xl)
                }
                .background(AppColors.backgroundLight)
            }
            .navigationTitle("Create Story Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if currentStep > 1 {
                        Button(action: {
                            goToPreviousStep()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.surfaceLight)
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(AppColors.primaryIndigo)
                            }
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle()
                                    .stroke(AppColors.borderLight, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
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
                }
            }
            .toolbarBackground(AppColors.backgroundLight, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(error?.localizedDescription ?? "An unknown error occurred")
        }
        .alert("Generate Story Book?", isPresented: $showingGenerationAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Generate") {
                Task {
                    await generateBook()
                }
            }
        } message: {
            if let draft = activeDraft {
                Text("This will generate illustrations for all \(draft.pageCount) pages. Continue in background?")
            }
        }
        // Overlays instead of sheet/fullScreenCover to avoid presenter conflicts
        .overlay(alignment: .center) {
            if isShowingProgress {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    DraftCreationProgressView(
                        productCategory: productCategory,
                        onComplete: { _ in },
                        onError: { errorMessage in
                            error = DraftError.serverError(errorMessage)
                            showingError = true
                            isShowingProgress = false
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.backgroundLight)
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .overlay(alignment: .center) {
            if showingPreview, let draft = activeDraft {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    NavigationView {
                        VStack(spacing: 16) {
                            Text("Test Draft Preview")
                                .font(.title)
                            Text(draft.title)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            Button(action: {
                                showingPreview = false
                                userTheme = ""
                                onDraftCreated(draft)
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
                            .padding(.top, 12)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppColors.backgroundLight)
                        .navigationTitle("Test Sheet")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                    .cardStyle()
                    .onAppear {
                        #if DEBUG
                        print("🧪 Presenting Test Draft Preview Overlay for draft: \(draft.id)")
                        #endif
                    }
                }
                .transition(.opacity)
                .zIndex(200)
            }
        }
        // Debug state logs
        .onChange(of: isShowingProgress) { _, presenting in
            #if DEBUG
            print("🔁 isShowingProgress = \(presenting)")
            #endif
        }
        .onChange(of: showingPreview) { _, presenting in
            #if DEBUG
            print("🔁 showingPreview = \(presenting)")
            #endif
        }
        // Align with other sheets: rely on pageMargins() inside ScrollView
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: AppSpacing.xl) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppColors.primaryIndigo)
            
            Text("Preparing story creation...")
                .font(AppTypography.bodyLarge)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 200)
    }
    // MARK: - Progress Bar
    private var progressBar: some View {
        VStack(spacing: AppSpacing.xs) {
            HStack(spacing: 4) {
                ForEach(1...3, id: \.self) { step in
                    Rectangle()
                        .fill(step <= currentStep ? productColor : AppColors.borderLight)
                        .frame(height: 4)
                }
            }

            Text("Step \(currentStep) of 3")
                .font(AppTypography.captionLarge)
                .foregroundColor(AppColors.textSecondary)
                .padding(.top, 4)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
        .background(AppColors.backgroundLight)
    }

    // MARK: - Can Proceed
    private var canProceedToNextStep: Bool {
        switch currentStep {
        case 1: return selectedStoryType != nil
        case 2: return !userTheme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 3: return activeDraft != nil
        default: return false
        }
    }

    // MARK: - Navigation Functions
    private func goToNextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            transitionEdge = .trailing
            currentStep += 1
        }
    }

    private func goToPreviousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            transitionEdge = .leading
            currentStep -= 1
        }
    }

    // MARK: - Step 1: Story Type Selection
    private var step1StoryTypeSelection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // Header
            VStack(alignment: .center, spacing: AppSpacing.md) {
                Text("Choose Story Type")
                    .font(AppTypography.categoryTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 10)
            }

            // Story types grid
            LazyVGrid(columns: GridLayouts.categoryGrid, spacing: AppSpacing.md) {
                ForEach(StoryType.allCases, id: \.rawValue) { storyType in
                    StoryTypeCard(
                        storyType: storyType,
                        isSelected: selectedStoryType == storyType,
                        productColor: productColor,
                        action: {
                            selectedStoryType = storyType
                            // Auto-advance to next step after brief delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                goToNextStep()
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Step 3: Draft Preview
    private var step3DraftPreview: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // Success message
            VStack(spacing: AppSpacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppColors.successGreen)

                Text("Story Draft Created!")
                    .font(AppTypography.headlineLarge)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                if let draft = activeDraft {
                    Text(draft.title)
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xl)

            // Draft info
            if let draft = activeDraft {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack {
                        Image(systemName: "book.closed.fill")
                            .foregroundColor(productColor)
                        Text("\(draft.pageCount) pages")
                            .bodyMedium()
                            .foregroundColor(AppColors.textPrimary)
                    }

                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(productColor)
                        Text("Age \(draft.ageGroup)")
                            .bodyMedium()
                            .foregroundColor(AppColors.textPrimary)
                    }

                    if !draft.focusTags.isEmpty {
                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundColor(productColor)
                            Text(draft.focusTags.joined(separator: ", "))
                                .bodyMedium()
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                }
                .cardStyle()
            }

            Spacer()

            // Generate button
            Button(action: {
                if let draft = activeDraft {
                    showingGenerationAlert = true
                }
            }) {
                HStack {
                    if isGeneratingBook {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isGeneratingBook ? "Starting Generation..." : "Generate Book")
                }
                .frame(maxWidth: .infinity)
            }
            .largeButtonStyle(backgroundColor: productColor)
            .disabled(isGeneratingBook)
            .opacity(isGeneratingBook ? 0.7 : 1.0)
            .childSafeTouchTarget()
        }
    }

    // MARK: - Step 2: Story Details (Draft Form)
    @ViewBuilder
    private var step2StoryDetails: some View {
        VStack(spacing: AppSpacing.sectionSpacing) {
            // Focus Tags Selection (moved to top, prefilled)
            focusTagsSelectionView

            // Age Group Selection
            ageGroupSelectionView

            // Theme Input
            themeInputView

            // Page Count Selection
            pageCountSelectionView

            // Custom Focus Input (Optional)
            customFocusInputView

            // Create Draft Button
            createDraftButtonView
        }
    }
    
    // MARK: - Product Header
    @ViewBuilder
    private var productHeaderView: some View {
        VStack(spacing: AppSpacing.md) {
            Text(productCategory.icon)
                .font(.system(size: AppSizing.iconSizes.xxl))
            
            VStack(spacing: AppSpacing.xs) {
                Text(productCategory.name)
                    .headlineLarge()
                    .foregroundColor(AppColors.textPrimary)
                
                Text(productCategory.description)
                    .bodyMedium()
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Token cost and duration info
                HStack(spacing: AppSpacing.md) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(AppColors.warningOrange)
                            .font(.system(size: 12))
                        Text("\(productCategory.tokenCost) tokens")
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
    
    // MARK: - Story Type Selection
    @ViewBuilder
    private var storyTypeSelectionView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Choose Story Type")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
            
            LazyVGrid(columns: GridLayouts.styleGrid, spacing: AppSpacing.grid.itemSpacing) {
                ForEach(StoryType.allCases, id: \.rawValue) { storyType in
                    StoryTypeCard(
                        storyType: storyType,
                        isSelected: selectedStoryType == storyType,
                        productColor: productColor
                    ) {
                        selectedStoryType = storyType
                    }
                }
            }
        }
        .cardStyle()
        .fixedSize(horizontal: false, vertical: true)
    }
    
    // MARK: - Age Group Selection
    private var ageGroupSelectionView: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Age Group")
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Stories are tailored for the selected age group")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
            }
            
            VStack(spacing: AppSpacing.xs) {
                ForEach(AgeGroup.allCases, id: \.rawValue) { ageGroup in
                    Button(action: {
                        selectedAgeGroup = ageGroup
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: AppSpacing.xxxs) {
                                Text("\(ageGroup.displayName) years")
                                    .font(AppTypography.titleMedium)
                                    .foregroundColor(selectedAgeGroup == ageGroup ? AppColors.primaryIndigo : AppColors.textPrimary)
                                
                                Text(ageGroup.description)
                                    .font(AppTypography.captionMedium)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            if selectedAgeGroup == ageGroup {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.primaryIndigo)
                                    .font(.system(size: 20))
                            }
                        }
                        .padding(AppSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                .fill(selectedAgeGroup == ageGroup ? AppColors.primaryIndigo.opacity(0.1) : AppColors.backgroundLight)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                .stroke(
                                    selectedAgeGroup == ageGroup ? AppColors.primaryIndigo : AppColors.textSecondary.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                    }
                }
            }
        }
        .cardStyle()
        .fixedSize(horizontal: false, vertical: true)
    }
    
    // MARK: - Theme Input
    private var themeInputView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Story Theme")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                TextField("Example: castle adventure with brave animals", text: $userTheme, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(AppTypography.bodyLarge)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(AppSpacing.md)
                    .background(AppColors.backgroundLight)
                    .cornerRadius(AppSizing.cornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                            .stroke(AppColors.primaryIndigo.opacity(0.3), lineWidth: 1)
                    )
                    .lineLimit(3...6)
                
                Text("Describe the main theme or adventure for your story (3-200 characters)")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
                
                // Character count
                HStack {
                    Spacer()
                    Text("\(userTheme.count)/200")
                        .font(AppTypography.captionSmall)
                        .foregroundColor(userTheme.count > 200 ? AppColors.errorRed : AppColors.textSecondary)
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Page Count Selection
    private var pageCountSelectionView: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Number of Pages")
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("4-8 pages recommended for children's books")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
            }
            
            // Adaptive grid prevents horizontal overflow and respects margins
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: AppSpacing.sm)], spacing: AppSpacing.sm) {
                ForEach([4, 6, 8, 12, 16, 20], id: \.self) { count in
                    let isRecommended = count <= 8
                    let isSelected = selectedPageCount == count

                    Button(action: { selectedPageCount = count }) {
                        VStack(spacing: AppSpacing.xxs) {
                            Text("\(count)")
                                .font(AppTypography.titleMedium)
                                .foregroundColor(isSelected ? .white : AppColors.textPrimary)

                            if isRecommended {
                                Text("✓")
                                    .font(AppTypography.captionSmall)
                                    .foregroundColor(isSelected ? .white.opacity(0.8) : AppColors.successGreen)
                            }
                        }
                        .frame(minWidth: 52, maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                .fill(isSelected ? AppColors.primaryIndigo : AppColors.backgroundLight)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                .stroke(
                                    isSelected ? AppColors.primaryIndigo : (isRecommended ? AppColors.successGreen.opacity(0.3) : AppColors.textSecondary.opacity(0.2)),
                                    lineWidth: 1
                                )
                        )
                    }
                    .childSafeTouchTarget()
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Focus Tags Selection
    private var focusTagsSelectionView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Story Focus")
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)

                Text("Select the main theme for your story")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            LazyVGrid(columns: GridLayouts.categoryGrid, spacing: AppSpacing.md) {
                ForEach(FocusTag.allCases, id: \.rawValue) { focusTag in
                    let isSelected = selectedFocusTag == focusTag

                    Button(action: {
                        selectedFocusTag = focusTag
                    }) {
                        VStack(spacing: AppSpacing.sm) {
                            // Icon
                            Image(systemName: focusTag.icon)
                                .font(.system(size: 32))
                                .foregroundColor(isSelected ? .white : productColor)
                                .frame(height: 40)

                            // Title
                            Text(focusTag.displayName)
                                .font(AppTypography.titleSmall)
                                .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .padding(AppSpacing.sm)
                        .frame(height: 140)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                                .fill(isSelected ? productColor : productColor.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                                        .stroke(
                                            isSelected ? productColor : AppColors.textSecondary.opacity(0.2),
                                            lineWidth: isSelected ? 2 : 1
                                        )
                                )
                        )
                    }
                    .childSafeTouchTarget()
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Custom Focus Input
    private var customFocusInputView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Custom Focus (Optional)")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                TextField("Example: Focus on teamwork and courage", text: $customFocus, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(AppSpacing.md)
                    .background(AppColors.backgroundLight)
                    .cornerRadius(AppSizing.cornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                            .stroke(AppColors.primaryIndigo.opacity(0.3), lineWidth: 1)
                    )
                    .lineLimit(2...4)
                
                Text("Additional focus description to guide story creation")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .cardStyle()
    }
    
    // MARK: - Create Draft Button
    private var createDraftButtonView: some View {
        VStack(spacing: AppSpacing.sm) {
            Button {
                Task {
                    await createDraft()
                }
            } label: {
                Text("Create Story Draft")
                    .frame(maxWidth: .infinity)
            }
            .largeButtonStyle(backgroundColor: canCreateDraft ? productColor : AppColors.buttonDisabled)
            .disabled(!canCreateDraft)
            .opacity(canCreateDraft ? 1.0 : 0.6)

            if !canCreateDraft {
                Text(createDraftValidationText)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.errorRed)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Computed Properties
    private var canCreateDraft: Bool {
        let trimmedTheme = userTheme.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTheme.count >= 3 && trimmedTheme.count <= 200
    }
    
    private var createDraftValidationText: String {
        let trimmedTheme = userTheme.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedTheme.isEmpty {
            return "Please enter a story theme"
        } else if trimmedTheme.count < 3 {
            return "Story theme must be at least 3 characters"
        } else if trimmedTheme.count > 200 {
            return "Story theme must be less than 200 characters"
        }
        
        return ""
    }
    
    private var productColor: Color {
        if !productCategory.color.isEmpty {
            return Color(hex: productCategory.color)
        }
        
        switch productCategory.productType {
        case "book": return Color(hex: "#D97706") // Amber-600
        default: return AppColors.primaryIndigo
        }
    }
    
    // MARK: - Methods
    private func createDraft() async {
        guard let storyType = selectedStoryType else { return }

        let trimmedTheme = userTheme.trimmingCharacters(in: .whitespacesAndNewlines)

        let request = CreateDraftRequest(
            theme: trimmedTheme,
            storyType: storyType,
            ageGroup: selectedAgeGroup,
            pageCount: selectedPageCount,
            focusTags: [selectedFocusTag],
            customFocus: customFocus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : customFocus.trimmingCharacters(in: .whitespacesAndNewlines),
            aiGenerated: true // Manual creation still uses AI for story generation
        )
        
        // Validate request
        if let validationError = draftService.validateDraftRequest(request) {
            error = DraftError.validationError(validationError)
            showingError = true
            return
        }
        
        #if DEBUG
        print("📝 StoryDraftCreationView: Creating draft with theme: \(trimmedTheme)")
        print("📝 Story Type: \(storyType.displayName)")
        print("📝 Age Group: \(selectedAgeGroup.displayName)")
        print("📝 Page Count: \(selectedPageCount)")
        print("📝 Focus Tag: \(selectedFocusTag.displayName)")
        print("📝 Custom Focus: \(customFocus)")
        #endif
        
        await MainActor.run {
            isShowingProgress = true
        }
        
        do {
            let response = try await draftService.createDraft(request)
            await MainActor.run {
                isShowingProgress = false
                activeDraft = response.draft
                // Navigate to step 3 to show draft preview
                goToNextStep()
            }
        } catch {
            await MainActor.run {
                self.error = error
                showingError = true
                isShowingProgress = false
            }
        }
    }

    // MARK: - Generate Book
    private func generateBook() async {
        guard let draft = activeDraft, let storyType = selectedStoryType else { return }

        await MainActor.run {
            isGeneratingBook = true
        }

        #if DEBUG
        print("📖 StoryDraftCreationView: Starting book generation for draft: \(draft.id)")
        print("📖 Draft title: \(draft.title)")
        print("📖 Story type: \(storyType.rawValue)")
        print("📖 Page count: \(draft.pageCount)")
        #endif

        do {
            // Call the book generation endpoint
            let bookId = try await draftService.generateBookFromDraft(draft: draft, storyType: storyType.rawValue)

            #if DEBUG
            print("✅ Book generation started successfully")
            print("📖 Book ID: \(bookId)")
            #endif

            await MainActor.run {
                isGeneratingBook = false
                // Pass the draft back and dismiss - generation continues in background
                onDraftCreated(draft)
                onDismiss()
            }
        } catch {
            #if DEBUG
            print("❌ Book generation failed: \(error.localizedDescription)")
            #endif

            await MainActor.run {
                self.error = error
                showingError = true
                isGeneratingBook = false
            }
        }
    }
}

// MARK: - Story Type Card
struct StoryTypeCard: View {
    let storyType: StoryType
    let isSelected: Bool
    let productColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: storyType.icon)
                    .font(.system(size: 32))
                    .foregroundColor(isSelected ? .white : productColor)
                
                VStack(spacing: AppSpacing.xxs) {
                    Text(storyType.displayName)
                        .font(AppTypography.titleSmall)
                        .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text(storyType.description)
                        .font(AppTypography.captionMedium)
                        .foregroundColor(isSelected ? .white.opacity(0.9) : AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
            }
            .padding(AppSpacing.sm)
            .frame(height: 140)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                    .fill(isSelected ? productColor : productColor.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                            .stroke(
                                isSelected ? productColor : AppColors.textSecondary.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .childSafeTouchTarget()
    }
}

// MARK: - Placeholder Views
struct DraftCreationProgressView: View {
    let productCategory: ProductCategory
    let onComplete: (StoryDraft) -> Void
    let onError: (String) -> Void
    
    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppColors.primaryIndigo)
            
            Text("Creating your story...")
                .headlineMedium()
                .foregroundColor(AppColors.textPrimary)
            
            Text("AI is crafting a personalized story for you")
                .bodyMedium()
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundLight)
    }
}

struct DraftPreviewView: View {
    let draft: StoryDraft
    let productCategory: ProductCategory
    let onDismiss: () -> Void
    let onGenerateBook: (StoryDraft) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    Text("Story Draft Created!")
                        .headlineLarge()
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(draft.title)
                        .titleMedium()
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Generate Book") {
                        onGenerateBook(draft)
                    }
                    .largeButtonStyle(backgroundColor: AppColors.primaryIndigo)
                    .childSafeTouchTarget()
                }
                .pageMargins()
                .padding(.vertical, AppSpacing.sectionSpacing)
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("Draft Ready")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
        .cardStyle()
    }
}
