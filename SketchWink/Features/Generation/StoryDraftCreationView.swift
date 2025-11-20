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
    @StateObject private var booksService = BooksService.shared
    @StateObject private var localization = LocalizationManager.shared
    @State private var currentStep = 1
    @State private var selectedTheme: BookThemeOption? // UPDATED: Use dynamic BookThemeOption
    @State private var selectedAgeGroup: AgeGroup = .preschool
    @State private var userTheme = ""
    @State private var selectedPageCount = 4
    @State private var selectedFocusTag: BookFocusTag? // UPDATED: Use dynamic BookFocusTag
    @State private var customFocus = ""
    @State private var draftCreationState: DraftCreationState = .idle
    @State private var isLoading = false
    @State private var isLoadingThemes = false
    @State private var error: Error?
    @State private var showingError = false
    @State private var isShowingProgress = false
    @State private var showingPreview = false
    @State private var activeDraft: StoryDraft?
    @State private var transitionEdge: Edge = .trailing

    // Step 3: Draft Review States
    @State private var isEditingDraft = false
    @State private var isSavingDraft = false
    @State private var editedPageTexts: [String] = []
    @State private var isGeneratingBook = false
    @State private var showingGenerationAlert = false

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
                                step3DraftReview
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
            .navigationTitle("books.create.story.book".localized)
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
                                    .foregroundColor(AppColors.primaryPink)
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
        .task {
            // Always load themes and focus tags to get current language translations
            await loadThemesAndFocusTags()
        }
        .onChange(of: localization.currentLanguage) { oldValue, newValue in
            // Reload themes and focus tags when language changes
            #if DEBUG
            print("🌍 StoryDraftCreationView: Language changed from \(oldValue.displayName) to \(newValue.displayName)")
            #endif

            Task {
                await reloadTranslatedContent()
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(error?.localizedDescription ?? "An unknown error occurred")
        }
        .alert("books.generate.confirmation.title".localized, isPresented: $showingGenerationAlert) {
            Button("books.cancel".localized, role: .cancel) { }
            Button("books.generate.book".localized) {
                Task {
                    await generateBook()
                }
            }
        } message: {
            if let draft = activeDraft {
                Text(String(format: "books.generate.confirmation.message".localized, draft.pageCount))
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
        // Note: BookDraftReviewView fullScreenCover removed - now integrated as step 3
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: AppSpacing.xl) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppColors.primaryPink)

            Text("books.preparing".localized)
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

            Text(String(format: "books.step.of.3".localized, currentStep))
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
        case 1: return selectedTheme != nil  // UPDATED: Use selectedTheme
        case 2: return !userTheme.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    // MARK: - Step 1: Story Type Selection (Dynamic from Backend)
    private var step1StoryTypeSelection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            VStack(alignment: .center, spacing: AppSpacing.md) {
                Text("books.choose.story.type".localized)
                    .font(AppTypography.categoryTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 10)

                if isLoadingThemes {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xl)
                } else {
                    LazyVGrid(columns: GridLayouts.styleGrid, spacing: AppSpacing.grid.itemSpacing) {
                        ForEach(booksService.themes) { theme in
                            BookThemeCard(
                                theme: theme,
                                isSelected: selectedTheme?.id == theme.id,
                                productColor: productColor,
                                action: {
                                    selectedTheme = theme
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

    // MARK: - Step 3: Draft Review
    @ViewBuilder
    private var step3DraftReview: some View {
        if let draft = activeDraft {
            VStack(spacing: AppSpacing.sectionSpacing) {
            // Book Header
            VStack(spacing: AppSpacing.xs) {
                Text(draft.title)
                    .headlineLarge()
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(draft.theme)
                    .bodyMedium()
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Book Stats
                HStack(spacing: AppSpacing.md) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(productColor)
                            .font(.system(size: 12))
                        Text("\(draft.pageCount) pages")
                            .captionLarge()
                            .foregroundColor(AppColors.textSecondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .foregroundColor(AppColors.primaryPurple)
                            .font(.system(size: 12))
                        Text("Age \(draft.ageGroup)")
                            .captionLarge()
                            .foregroundColor(AppColors.textSecondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(AppColors.warningOrange)
                            .font(.system(size: 12))
                        Text("\(draft.pageCount * 2) tokens")
                            .captionLarge()
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(.top, AppSpacing.xs)
            }
            .cardStyle()

            // Pages Review Section
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("books.story.pages".localized)
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.textPrimary)

                    Text("books.review.edit.desc".localized)
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                }

                // Simple page cards - just page number and text
                ForEach(Array(editedPageTexts.enumerated()), id: \.offset) { index, pageText in
                    SimplePageCard(
                        pageNumber: index + 1,
                        pageText: $editedPageTexts[index],
                        isEditing: isEditingDraft,
                        productColor: productColor
                    )
                }
            }
            .cardStyle()

            // Bottom Buttons
            bottomButtonsView
            }
        } else {
            EmptyView()
        }
    }

    // Bottom Buttons for Step 3
    private var bottomButtonsView: some View {
        VStack(spacing: AppSpacing.sm) {
            if isEditingDraft {
                // Edit Mode: Cancel + Save buttons
                Button {
                    cancelEditingDraft()
                } label: {
                    Text("books.cancel".localized)
                        .font(AppTypography.titleMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.buttonPadding.large.vertical)
                        .background(AppColors.backgroundLight)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(AppColors.borderLight, lineWidth: 2)
                        )
                }
                .disabled(isSavingDraft)

                Button {
                    Task {
                        await saveDraftChanges()
                    }
                } label: {
                    HStack {
                        if isSavingDraft {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isSavingDraft ? "books.saving".localized : "books.update".localized)
                    }
                    .largeButtonStyle(
                        backgroundColor: productColor,
                        isDisabled: isSavingDraft
                    )
                }
                .disabled(isSavingDraft)
            } else {
                // Review Mode: Edit + Generate buttons
                Button {
                    isEditingDraft = true
                } label: {
                    Text("books.edit".localized)
                        .font(AppTypography.titleMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.buttonPadding.large.vertical)
                        .background(AppColors.backgroundLight)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(AppColors.borderLight, lineWidth: 2)
                        )
                }
                .disabled(isGeneratingBook)

                Button {
                    showingGenerationAlert = true
                } label: {
                    HStack {
                        if isGeneratingBook {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isGeneratingBook ? "books.generating".localized : "books.generate.book".localized)
                    }
                    .largeButtonStyle(
                        backgroundColor: productColor,
                        isDisabled: isGeneratingBook
                    )
                }
                .disabled(isGeneratingBook)
            }
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
    
    // MARK: - Story Type Selection (Dynamic from Backend)
    @ViewBuilder
    private var storyTypeSelectionView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Choose Story Type")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)

            if isLoadingThemes {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .tint(productColor)
            } else if booksService.themes.isEmpty {
                Text("No themes available")
                    .bodyMedium()
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(columns: GridLayouts.styleGrid, spacing: AppSpacing.grid.itemSpacing) {
                    ForEach(booksService.themes) { theme in
                        BookThemeCard(
                            theme: theme,
                            isSelected: selectedTheme?.id == theme.id,
                            productColor: productColor
                        ) {
                            selectedTheme = theme
                        }
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
                    Text("books.age.group".localized)
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.textPrimary)

                    Text("books.age.group.desc".localized)
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
                                Text("\(ageGroup.displayName) \("books.age.years".localized)")
                                    .font(AppTypography.titleMedium)
                                    .foregroundColor(selectedAgeGroup == ageGroup ? AppColors.primaryPink : AppColors.textPrimary)

                                Text(ageGroup.description)
                                    .font(AppTypography.captionMedium)
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Spacer()

                            if selectedAgeGroup == ageGroup {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.primaryPink)
                                    .font(.system(size: 20))
                            }
                        }
                        .padding(AppSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                .fill(selectedAgeGroup == ageGroup ? AppColors.primaryPink.opacity(0.1) : AppColors.backgroundLight)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                .stroke(
                                    selectedAgeGroup == ageGroup ? AppColors.primaryPink : AppColors.textSecondary.opacity(0.2),
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
            Text("books.theme.input".localized)
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                TextField("books.theme.placeholder".localized, text: $userTheme, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(AppTypography.bodyLarge)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(AppSpacing.md)
                    .background(AppColors.backgroundLight)
                    .cornerRadius(AppSizing.cornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                            .stroke(AppColors.primaryPink.opacity(0.3), lineWidth: 1)
                    )
                    .lineLimit(3...6)
                
                Text("books.theme.description".localized)
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
                    Text("books.page.count".localized)
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.textPrimary)

                    Text("books.page.count.desc".localized)
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
            }
            
            // Adaptive grid prevents horizontal overflow and respects margins
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: AppSpacing.sm)], spacing: AppSpacing.sm) {
                ForEach([4, 6, 8, 12], id: \.self) { count in
                    let isSelected = selectedPageCount == count

                    Button(action: { selectedPageCount = count }) {
                        Text("\(count)")
                            .font(AppTypography.titleMedium)
                            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                            .frame(minWidth: 52, maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                            .background(
                                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                    .fill(isSelected ? AppColors.primaryPink : AppColors.backgroundLight)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                    .stroke(
                                        isSelected ? AppColors.primaryPink : AppColors.textSecondary.opacity(0.2),
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
                Text("books.focus.tags".localized)
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)

                Text("books.focus.tags.desc".localized)
                    .font(AppTypography.captionLarge)
                    .foregroundColor(AppColors.textSecondary)
            }

            if isLoadingThemes {
                // Loading state
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .tint(productColor)
            } else {
                // Focus tags grid (dynamic from backend)
                LazyVGrid(columns: GridLayouts.categoryGrid, spacing: AppSpacing.md) {
                    ForEach(booksService.focusTags) { focusTag in
                        let isSelected = selectedFocusTag?.id == focusTag.id

                        Button(action: {
                            selectedFocusTag = focusTag
                        }) {
                            VStack(spacing: AppSpacing.sm) {
                                // Icon
                                Image(systemName: focusTag.icon)
                                    .font(.system(size: 32))
                                    .foregroundColor(isSelected ? .white : productColor)
                                    .frame(height: 40)

                                // Title (translated from backend)
                                Text(focusTag.name)
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
        }
        .cardStyle()
    }
    
    // MARK: - Custom Focus Input
    private var customFocusInputView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("books.custom.focus".localized)
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                TextField("books.custom.focus.placeholder".localized, text: $customFocus, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(AppSpacing.md)
                    .background(AppColors.backgroundLight)
                    .cornerRadius(AppSizing.cornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                            .stroke(AppColors.primaryPink.opacity(0.3), lineWidth: 1)
                    )
                    .lineLimit(2...4)


                Text("books.custom.focus.desc".localized)
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
                Text("books.create.draft".localized)
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
            return "books.validation.theme.required".localized
        } else if trimmedTheme.count < 3 {
            return "books.validation.theme.min".localized
        } else if trimmedTheme.count > 200 {
            return "books.validation.theme.max".localized
        }
        
        return ""
    }
    
    private var productColor: Color {
        // Always use primary pink for books tab
        return AppColors.primaryPink
    }
    
    // MARK: - Methods
    private func createDraft() async {
        guard let selectedTheme = selectedTheme else { return }

        let trimmedTheme = userTheme.trimmingCharacters(in: .whitespacesAndNewlines)

        let request = CreateDraftRequest(
            theme: trimmedTheme,
            storyType: StoryType.bedtimeStory, // Fallback enum value for API compatibility
            ageGroup: selectedAgeGroup,
            pageCount: selectedPageCount,
            focusTags: [], // Backend doesn't use this anymore - uses theme ID
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
        print("📝 Selected Theme: \(selectedTheme.name) (ID: \(selectedTheme.id))")
        print("📝 Age Group: \(selectedAgeGroup.displayName)")
        print("📝 Page Count: \(selectedPageCount)")
        if let focusTag = selectedFocusTag {
            print("📝 Focus Tag: \(focusTag.name) (ID: \(focusTag.id))")
        }
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
                editedPageTexts = response.draft.pageTexts
                // Navigate to step 3 for draft review
                transitionEdge = .trailing
                currentStep = 3
            }
        } catch {
            await MainActor.run {
                self.error = error
                showingError = true
                isShowingProgress = false
            }
        }
    }

    // MARK: - Step 3 Helper Methods
    private func cancelEditingDraft() {
        guard let draft = activeDraft else { return }
        editedPageTexts = draft.pageTexts
        isEditingDraft = false
    }

    private func saveDraftChanges() async {
        guard let draft = activeDraft else { return }

        let hasChanges = editedPageTexts != draft.pageTexts
        guard hasChanges else {
            await MainActor.run {
                isEditingDraft = false
            }
            return
        }

        await MainActor.run {
            isSavingDraft = true
        }

        let updates = UpdateDraftRequest(
            title: nil,
            pageTexts: editedPageTexts
        )

        do {
            let updatedDraft = try await draftService.updateDraft(id: draft.id, updates: updates)
            await MainActor.run {
                activeDraft = updatedDraft
                isEditingDraft = false
                isSavingDraft = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                showingError = true
                isSavingDraft = false
            }
        }
    }

    // MARK: - Load Themes & Focus Tags from Backend

    private func loadThemesAndFocusTags() async {
        isLoadingThemes = true

        do {
            // Load themes and focus tags in parallel
            async let themesTask = booksService.getThemes()
            async let focusTagsTask = booksService.getFocusTags()

            _ = try await (themesTask, focusTagsTask)

            #if DEBUG
            print("✅ StoryDraftCreationView: Loaded \(booksService.themes.count) themes and \(booksService.focusTags.count) focus tags")
            #endif

            // Auto-select first focus tag if available and nothing selected
            if selectedFocusTag == nil, let firstFocusTag = booksService.focusTags.first {
                selectedFocusTag = firstFocusTag
            }

        } catch {
            #if DEBUG
            print("❌ StoryDraftCreationView: Error loading themes/focus tags - \(error)")
            #endif

            self.error = error
            showingError = true
        }

        isLoadingThemes = false
    }

    private func reloadTranslatedContent() async {
        isLoadingThemes = true

        do {
            // Save currently selected focus tag ID to restore after reload
            let currentFocusTagId = selectedFocusTag?.id
            let currentThemeId = selectedTheme?.id

            // Reload themes and focus tags in parallel (backend provides translated content)
            async let themesTask = booksService.getThemes()
            async let focusTagsTask = booksService.getFocusTags()

            _ = try await (themesTask, focusTagsTask)

            await MainActor.run {
                // Restore theme selection with updated translation
                if let themeId = currentThemeId {
                    selectedTheme = booksService.themes.first { $0.id == themeId }
                }

                // Restore focus tag selection with updated translation
                if let tagId = currentFocusTagId {
                    selectedFocusTag = booksService.focusTags.first { $0.id == tagId }
                } else if selectedFocusTag == nil, let firstTag = booksService.focusTags.first {
                    // Auto-select first tag if nothing was selected
                    selectedFocusTag = firstTag
                }
            }

            #if DEBUG
            print("🌐 StoryDraftCreationView: Reloaded translated content - \(booksService.themes.count) themes, \(booksService.focusTags.count) focus tags")
            print("🎯 StoryDraftCreationView: Restored theme: \(selectedTheme?.name ?? "none")")
            print("🎯 StoryDraftCreationView: Restored focus tag: \(selectedFocusTag?.name ?? "none")")
            #endif

        } catch {
            #if DEBUG
            print("❌ StoryDraftCreationView: Error reloading translated content - \(error)")
            #endif

            self.error = error
            showingError = true
        }

        isLoadingThemes = false
    }

    private func generateBook() async {
        guard let draft = activeDraft else { return }

        await MainActor.run {
            isGeneratingBook = true
        }

        let options = GenerateBookFromDraftRequest(
            model: "seedream",
            quality: "standard",
            dimensions: "a4"
        )

        do {
            _ = try await draftService.generateBookFromDraft(draftId: draft.id, options: options)

            await MainActor.run {
                isGeneratingBook = false
                // Dismiss the creation flow and navigate to books
                onDismiss()
            }
        } catch {
            await MainActor.run {
                isGeneratingBook = false
                self.error = error
                showingError = true
            }
        }
    }

}

// MARK: - Story Type Card (DEPRECATED - use BookThemeCard)
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

// MARK: - Book Theme Card (Dynamic from Backend)
struct BookThemeCard: View {
    let theme: BookThemeOption
    let isSelected: Bool
    let productColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Icon area (matching bedtime stories layout)
                Rectangle()
                    .fill(productColor.opacity(0.2))
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .overlay(
                        Image(systemName: "book.fill")
                            .font(.system(size: 40))
                            .foregroundColor(productColor)
                    )

                // Text area (matching bedtime stories layout exactly)
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(theme.name)
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Text(theme.description)
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 100)
            }
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .background(productColor.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                    .stroke(
                        isSelected ? productColor : productColor.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg))
            .shadow(
                color: productColor.opacity(isSelected ? 0.3 : 0.1),
                radius: 10,
                x: 0,
                y: 10
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
                .tint(AppColors.primaryPink)

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

// Note: SimplePageCard is defined in BookDraftReviewView.swift and shared across files

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
                    .largeButtonStyle(backgroundColor: AppColors.primaryPink)
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
