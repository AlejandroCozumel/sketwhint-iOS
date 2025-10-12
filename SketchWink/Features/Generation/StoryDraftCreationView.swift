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
    @State private var selectedStoryType: StoryType = .adventureStory
    @State private var selectedAgeGroup: AgeGroup = .preschool
    @State private var userTheme = ""
    @State private var selectedPageCount = 4
    @State private var selectedFocusTags: Set<FocusTag> = []
    @State private var customFocus = ""
    @State private var draftCreationState: DraftCreationState = .idle
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showingError = false
    @State private var isShowingProgress = false
    @State private var showingPreview = false
    @State private var activeDraft: StoryDraft?
    
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
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    if isLoading {
                        loadingView
                    } else {
                        draftFormView
                    }
                }
                .pageMargins()
                .padding(.vertical, AppSpacing.sectionSpacing)
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("Create Story")
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
                .tint(AppColors.primaryBlue)
            
            Text("Preparing story creation...")
                .font(AppTypography.bodyLarge)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 200)
    }
    
    
    
    // MARK: - Draft Form
    @ViewBuilder
    private var draftFormView: some View {
        VStack(spacing: AppSpacing.sectionSpacing) {
            // Product Header
            productHeaderView
            
            // Story Type Selection
            storyTypeSelectionView
            
            // Age Group Selection
            ageGroupSelectionView
            
            // Theme Input
            themeInputView
            
            // Page Count Selection
            pageCountSelectionView
            
            // Focus Tags Selection (Optional)
            focusTagsSelectionView
            
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
                                    .foregroundColor(selectedAgeGroup == ageGroup ? AppColors.primaryBlue : AppColors.textPrimary)
                                
                                Text(ageGroup.description)
                                    .font(AppTypography.captionMedium)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            Spacer()
                            
                            if selectedAgeGroup == ageGroup {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.primaryBlue)
                                    .font(.system(size: 20))
                            }
                        }
                        .padding(AppSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                .fill(selectedAgeGroup == ageGroup ? AppColors.primaryBlue.opacity(0.1) : AppColors.backgroundLight)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                .stroke(
                                    selectedAgeGroup == ageGroup ? AppColors.primaryBlue : AppColors.textSecondary.opacity(0.2),
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
                            .stroke(AppColors.primaryBlue.opacity(0.3), lineWidth: 1)
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
                                .fill(isSelected ? AppColors.primaryBlue : AppColors.backgroundLight)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                .stroke(
                                    isSelected ? AppColors.primaryBlue : (isRecommended ? AppColors.successGreen.opacity(0.3) : AppColors.textSecondary.opacity(0.2)),
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
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Focus Tags (Optional)")
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Choose themes to emphasize in your story")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
                
                if !selectedFocusTags.isEmpty {
                    Button("Clear All") {
                        selectedFocusTags.removeAll()
                    }
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.primaryBlue)
                }
            }
            
            LazyVGrid(columns: GridLayouts.threeColumnGrid, spacing: AppSpacing.grid.itemSpacing) {
                ForEach(FocusTag.allCases, id: \.rawValue) { focusTag in
                    let isSelected = selectedFocusTags.contains(focusTag)
                    
                    Button(action: {
                        if isSelected {
                            selectedFocusTags.remove(focusTag)
                        } else {
                            selectedFocusTags.insert(focusTag)
                        }
                    }) {
                        VStack(spacing: AppSpacing.xs) {
                            Image(systemName: focusTag.icon)
                                .font(.system(size: 20))
                                .foregroundColor(isSelected ? .white : AppColors.primaryBlue)
                            
                            Text(focusTag.displayName)
                                .font(AppTypography.captionMedium)
                                .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(height: 70)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                .fill(isSelected ? AppColors.primaryBlue : AppColors.backgroundLight)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                .stroke(
                                    isSelected ? AppColors.primaryBlue : AppColors.textSecondary.opacity(0.2),
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
                            .stroke(AppColors.primaryBlue.opacity(0.3), lineWidth: 1)
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
            Button("Create Story Draft") {
                Task {
                    await createDraft()
                }
            }
            .largeButtonStyle(backgroundColor: canCreateDraft ? productColor : AppColors.buttonDisabled)
            .disabled(!canCreateDraft)
            .opacity(canCreateDraft ? 1.0 : 0.6)
            .childSafeTouchTarget()
            
            if !canCreateDraft {
                Text(createDraftValidationText)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.errorRed)
                    .multilineTextAlignment(.center)
            }
        }
        .cardStyle()
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
        default: return AppColors.primaryBlue
        }
    }
    
    // MARK: - Methods
    private func createDraft() async {
        let trimmedTheme = userTheme.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let request = CreateDraftRequest(
            theme: trimmedTheme,
            storyType: selectedStoryType,
            ageGroup: selectedAgeGroup,
            pageCount: selectedPageCount,
            focusTags: selectedFocusTags.isEmpty ? nil : Array(selectedFocusTags),
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
        print("📝 Story Type: \(selectedStoryType.displayName)")
        print("📝 Age Group: \(selectedAgeGroup.displayName)")
        print("📝 Page Count: \(selectedPageCount)")
        print("📝 Focus Tags: \(selectedFocusTags.map { $0.displayName })")
        print("📝 Custom Focus: \(customFocus)")
        #endif
        
        await MainActor.run {
            isShowingProgress = true
        }
        
        do {
            let response = try await draftService.createDraft(request)
            await MainActor.run {
                isShowingProgress = false
                onDraftCreated(response.draft)
            }
        } catch {
            await MainActor.run {
                self.error = error
                showingError = true
                isShowingProgress = false
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
                .tint(AppColors.primaryBlue)
            
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
                    .largeButtonStyle(backgroundColor: AppColors.primaryBlue)
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
