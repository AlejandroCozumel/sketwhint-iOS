import SwiftUI

struct BedtimeStoriesCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = BedtimeStoriesService.shared
    @StateObject private var tokenManager = TokenBalanceManager.shared
    @StateObject private var localization = LocalizationManager.shared

    @State private var currentStep = 1
    @State private var isLoading = false
    @State private var error: String?
    @State private var showingError = false
    @State private var transitionEdge: Edge = .trailing

    // Step 1: Theme
    @State private var selectedTheme: BedtimeThemeOption?
    @State private var category: BedtimeStoryCategory?

    // Step 2: Details
    @State private var selectedFocusTag: BedtimeFocusTag?
    @State private var hasPreselectedFocusTag = false
    @State private var prompt = ""
    @State private var selectedLength: BedtimeStoryLength = .short
    @State private var characterName = ""
    @State private var ageGroup = "stories.3to5.years.old".localized
    @State private var selectedVoice = "nova" // Default to Sofia
    @State private var voices: [Voice] = []

    private enum FocusField {
        case prompt
        case characterName
    }
    @FocusState private var focusedField: FocusField?

    private enum EditFocusField {
        case title
        case story
    }
    @FocusState private var editFocusField: EditFocusField?

    // Step 3: Draft
    @State private var currentDraft: BedtimeDraft?
    @State private var showingTokenConfirmation = false
    @State private var showingGenerationAlert = false

    // Edit mode states
    @State private var isEditMode = false
    @State private var editedTitle = ""
    @State private var editedStoryText = ""

    init(category: BedtimeStoryCategory?) {
        self._category = State(initialValue: category)
    }

    private var selectedVoiceDescription: String? {
        voices.first { $0.id == selectedVoice }?.description
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressBar

            // Main content
            if currentStep == 3 && isEditMode {
                VStack(spacing: AppSpacing.lg) {
                    step3DraftPreviewAndGenerate
                }
                .background(AppColors.backgroundLight)
                .ignoresSafeArea(.keyboard)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: AppSpacing.lg) {
                            switch currentStep {
                            case 1:
                                step1ThemeSelection
                                    .transition(.asymmetric(insertion: .move(edge: transitionEdge), removal: .move(edge: transitionEdge == .trailing ? .leading : .trailing)))
                                    .id("step1")
                            case 2:
                                step2StoryDetails
                                    .transition(.asymmetric(insertion: .move(edge: transitionEdge), removal: .move(edge: transitionEdge == .trailing ? .leading : .trailing)))
                                    .id("step2")
                            case 3:
                                step3DraftPreviewAndGenerate
                                    .transition(.asymmetric(insertion: .move(edge: transitionEdge), removal: .move(edge: transitionEdge == .trailing ? .leading : .trailing)))
                                    .id("step3")
                            default:
                                EmptyView()
                            }
                        }
                        .padding(AppSpacing.md)
                        .padding(.bottom, AppSpacing.xl)
                    }
                    .dismissKeyboardOnScroll()
                    .simultaneousGesture(
                        DragGesture().onChanged { _ in
                            focusedField = nil
                        }
                    )
                    .onChange(of: currentStep) { oldValue, newValue in
                        withAnimation {
                            proxy.scrollTo("step\(newValue)", anchor: .top)
                        }
                    }
                    .animation(.easeInOut, value: currentStep)
                    .background(AppColors.backgroundLight)
                }
            }
        }
        .navigationTitle("stories.create.bedtime.story".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if currentStep > 1 {
                    Button(action: {
                        transitionEdge = .leading
                        currentStep -= 1
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
                    .accessibilityLabel("common.back".localized)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    dismiss()
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
                .accessibilityLabel("common.close".localized)
            }
        }
        .toolbarBackground(AppColors.backgroundLight, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await loadConfigAndData()
        }
        .onChange(of: localization.currentLanguage) { oldValue, newValue in
            Task {
                await reloadTranslatedContent()
            }
        }
        .alert("common.error".localized, isPresented: $showingError) {
            Button("common.ok".localized) { }
        } message: {
            Text(error ?? "stories.unknown.error".localized)
        }
        .alert("stories.confirm.generation".localized, isPresented: $showingTokenConfirmation) {
            Button("common.cancel".localized, role: .cancel) { }
            Button("stories.generate".localized) {
                showingGenerationAlert = true
            }
        } message: {
            Text(String(format: "stories.cost.tokens".localized, selectedLength.tokenCost))
        }
        .alert("stories.generating.story".localized, isPresented: $showingGenerationAlert) {
            Button("stories.dismiss".localized) {
                Task { await generateStory() }
                dismiss()
            }
        } message: {
            Text("stories.background.generation".localized)
        }
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        VStack(spacing: AppSpacing.xs) {
            HStack(spacing: 4) {
                ForEach(1...3, id: \.self) { step in
                    Rectangle()
                        .fill(step <= currentStep ? AppColors.primaryIndigo : AppColors.borderLight)
                        .frame(height: 4)
                }
            }

            Text(String(format: "stories.step.of.3".localized, currentStep))
                .font(AppTypography.captionLarge)
                .foregroundColor(AppColors.textSecondary)
                .padding(.top, 4)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
        .background(AppColors.backgroundLight)
    }

    // MARK: - Step 1: Theme Selection
    private var step1ThemeSelection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            VStack(alignment: .center, spacing: AppSpacing.md) {
                Text("stories.choose.theme".localized)
                    .font(AppTypography.categoryTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 10)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xl)
                } else {
                    LazyVGrid(columns: GridLayouts.styleGrid, spacing: AppSpacing.grid.itemSpacing) {
                        ForEach(service.themes) { theme in
                            ThemeCard(
                                theme: theme,
                                isSelected: selectedTheme?.id == theme.id
                            ) {
                                selectedTheme = theme
                                transitionEdge = .trailing
                                currentStep = 2
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Step 2: Story Details
    private var step2StoryDetails: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // Focus Tags - First (like books flow)
            focusTagsSelectionView

            // Story Idea Input
            VStack(spacing: AppSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("stories.story.idea".localized)
                            .font(AppTypography.titleMedium)
                            .foregroundColor(AppColors.textPrimary)
                        Text("stories.story.idea.description".localized)
                            .font(AppTypography.captionLarge)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                }
                TextField("stories.placeholder.example".localized, text: $prompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(AppTypography.bodyLarge)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(AppSpacing.md)
                    .background(AppColors.backgroundLight)
                    .cornerRadius(AppSizing.cornerRadius.md)
                    .overlay(RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md).stroke(focusedField == .prompt ? AppColors.primaryIndigo : AppColors.borderLight, lineWidth: 1))
                    .lineLimit(3...6)
                    .focused($focusedField, equals: .prompt)
            }.cardStyle()

            // Character Name
            VStack(spacing: AppSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("stories.character.name.optional".localized)
                            .font(AppTypography.titleMedium)
                            .foregroundColor(AppColors.textPrimary)
                        Text("stories.character.give.name".localized)
                            .font(AppTypography.captionLarge)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                }
                TextField("stories.enter.character.name".localized, text: $characterName)
                    .textFieldStyle(.plain)
                    .font(AppTypography.bodyLarge)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(AppSpacing.md)
                    .background(AppColors.backgroundLight)
                    .cornerRadius(AppSizing.cornerRadius.md)
                    .overlay(RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md).stroke(focusedField == .characterName ? AppColors.primaryIndigo : AppColors.borderLight, lineWidth: 1))
                    .focused($focusedField, equals: .characterName)
            }.cardStyle()

            VStack(spacing: AppSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("stories.length".localized)
                            .font(AppTypography.titleMedium)
                            .foregroundColor(AppColors.textPrimary)
                        Text("stories.choose.length".localized)
                            .font(AppTypography.captionLarge)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                }
                HStack(spacing: AppSpacing.sm) {
                    ForEach(BedtimeStoryLength.allCases, id: \.rawValue) { length in
                        LengthButton(length: length, isSelected: selectedLength == length) {
                            selectedLength = length
                        }
                    }
                }
            }.cardStyle()

            VStack(spacing: AppSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("stories.narrator.voice".localized)
                            .font(AppTypography.titleMedium)
                            .foregroundColor(AppColors.textPrimary)
                        Text("stories.narrator.pick".localized)
                            .font(AppTypography.captionLarge)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                }

                Menu {
                    ForEach(voices) { voice in
                        Button(voice.name) { selectedVoice = voice.id }
                    }
                } label: {
                    HStack {
                        Text(voices.first(where: { $0.id == selectedVoice })?.name ?? "stories.select.voice".localized)
                            .font(AppTypography.bodyLarge)
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(AppColors.textSecondary)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.backgroundLight)
                    .cornerRadius(AppSizing.cornerRadius.md)
                    .overlay(RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md).stroke(AppColors.borderLight, lineWidth: 1))
                }

                if let description = selectedVoiceDescription {
                    Text(description)
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.primaryIndigo)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, AppSpacing.xs)
                }
            }.cardStyle()

            VStack(spacing: AppSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("stories.age.group".localized)
                            .font(AppTypography.titleMedium)
                            .foregroundColor(AppColors.textPrimary)
                        Text("stories.age.group.select".localized)
                            .font(AppTypography.captionLarge)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                }
                Menu {
                    Button("stories.3to5.years.old".localized) { ageGroup = "stories.3to5.years.old".localized }
                    Button("stories.5to7.years.old".localized) { ageGroup = "stories.5to7.years.old".localized }
                    Button("stories.7to10.years.old".localized) { ageGroup = "stories.7to10.years.old".localized }
                } label: {
                    HStack {
                        Text(ageGroup)
                            .font(AppTypography.bodyLarge)
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(AppColors.textSecondary)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.backgroundLight)
                    .cornerRadius(AppSizing.cornerRadius.md)
                    .overlay(RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md).stroke(AppColors.borderLight, lineWidth: 1))
                }
            }.cardStyle()

            createDraftButtonView
        }
    }

    // MARK: - Focus Tags Selection
    private var focusTagsSelectionView: some View {
        VStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("stories.focus.tags".localized)
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)

                Text("stories.focus.tags.desc".localized)
                    .font(AppTypography.captionLarge)
                    .foregroundColor(AppColors.textSecondary)
            }

            if isLoading && service.focusTags.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.xl)
            } else {
                LazyVGrid(columns: GridLayouts.categoryGrid, spacing: AppSpacing.md) {
                    ForEach(service.focusTags) { focusTag in
                        let isSelected = selectedFocusTag?.id == focusTag.id

                        Button(action: {
                            selectedFocusTag = focusTag
                        }) {
                            VStack(spacing: AppSpacing.sm) {
                                // Icon - Use Image(systemName:) for SF Symbols
                                Image(systemName: focusTag.icon)
                                    .font(.system(size: 32))
                                    .foregroundColor(isSelected ? .white : AppColors.primaryIndigo)
                                    .frame(height: 40)

                                // Title
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
                                    .fill(isSelected ? AppColors.primaryIndigo : AppColors.primaryIndigo.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                                            .stroke(
                                                isSelected ? AppColors.primaryIndigo : AppColors.textSecondary.opacity(0.2),
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

    // MARK: - Create Draft Button
    private var createDraftButtonView: some View {
        VStack(spacing: AppSpacing.sm) {
            Button {
                Task { await createDraft() }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "doc.text.fill")
                    }
                    Text(isLoading ? "stories.creating.draft".localized : "stories.create.draft.free".localized)
                }
                .largeButtonStyle(
                    backgroundColor: AppColors.primaryIndigo,
                    isDisabled: !canCreateDraft || isLoading
                )
            }
            .disabled(!canCreateDraft || isLoading)

            if !canCreateDraft {
                Text("stories.enter.story.idea".localized)
                    .captionMedium()
                    .foregroundColor(AppColors.errorRed)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var canCreateDraft: Bool {
        !prompt.isEmpty
    }

    // MARK: - Step 3: Draft Preview & Generate
    private var step3DraftPreviewAndGenerate: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            if isEditMode {
                // Edit mode layout
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("stories.story.title".localized)
                            .font(AppTypography.titleMedium)
                            .foregroundColor(AppColors.textPrimary)
                        TextField("stories.enter.story.title".localized, text: $editedTitle)
                            .textFieldStyle(.plain)
                            .font(AppTypography.headlineMedium)
                            .foregroundColor(AppColors.textPrimary)
                            .padding(AppSpacing.md)
                            .background(AppColors.backgroundLight)
                            .cornerRadius(AppSizing.cornerRadius.md)
                            .overlay(RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md).stroke(editFocusField == .title ? AppColors.primaryIndigo : AppColors.borderLight, lineWidth: editFocusField == .title ? 2 : 1))
                            .focused($editFocusField, equals: .title)
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("stories.story.text".localized)
                            .font(AppTypography.titleMedium)
                            .foregroundColor(AppColors.textPrimary)
                        TextEditor(text: $editedStoryText)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                            .padding(AppSpacing.md)
                            .background(AppColors.backgroundLight)
                            .cornerRadius(AppSizing.cornerRadius.md)
                            .overlay(RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md).stroke(editFocusField == .story ? AppColors.primaryIndigo : AppColors.borderLight, lineWidth: editFocusField == .story ? 2 : 1))
                            .focused($editFocusField, equals: .story)
                            .scrollContentBackground(.hidden)
                    }

                    Spacer() // Pushes buttons to the bottom

                    editModeButtonsView
                }
                .padding(.horizontal, AppSpacing.md)
            } else {
                // Review mode layout
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(currentDraft?.title ?? "stories.story.preview".localized)
                            .headlineLarge()
                            .foregroundColor(AppColors.textPrimary)

                        HStack(spacing: AppSpacing.md) {
                            Label(String(format: "stories.words".localized, currentDraft?.wordCount ?? 0), systemImage: "doc.text")
                            Label(String(format: "stories.estimated.duration".localized, currentDraft?.estimatedDuration ?? 0), systemImage: "clock")
                        }
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                    }

                    if let draft = currentDraft {
                        Text(draft.storyText)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)
                            .padding(AppSpacing.md)
                            .background(AppColors.backgroundLight)
                            .cornerRadius(AppSizing.cornerRadius.md)
                            .overlay(RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md).stroke(AppColors.borderLight, lineWidth: 1))
                    }

                    reviewModeButtonsView
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Review Mode Buttons
    private var reviewModeButtonsView: some View {
        VStack(spacing: AppSpacing.sm) {
            // Edit Button
            Button {
                enterEditMode()
            } label: {
                Text("stories.edit".localized)
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
            .disabled(isLoading)

            // Generate Story Button
            Button {
                showingTokenConfirmation = true
            } label: {
                Text(isLoading ? "stories.generating.story".localized : "stories.generate.story".localized)
                    .largeButtonStyle(
                        backgroundColor: AppColors.primaryIndigo,
                        isDisabled: isLoading
                    )
            }
            .disabled(isLoading)
        }
    }

    // MARK: - Edit Mode Buttons
    private var editModeButtonsView: some View {
        VStack(spacing: AppSpacing.sm) {
            // Cancel Button
            Button {
                exitEditMode()
            } label: {
                Text("common.cancel".localized)
                .font(AppTypography.titleMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.buttonPadding.large.vertical)
                .background(AppColors.backgroundLight)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppColors.borderLight, lineWidth: 1)
                )
            }
            .disabled(isLoading)

            // Save Button
            Button {
                Task { await saveDraft() }
            } label: {
                Text(isLoading ? "stories.saving".localized : "stories.save".localized)
                    .largeButtonStyle(
                        backgroundColor: AppColors.primaryIndigo,
                        isDisabled: !canSave || isLoading
                    )
            }
            .disabled(!canSave || isLoading)

            if !canSave {
                Text("stories.title.story.empty".localized)
                    .captionMedium()
                    .foregroundColor(AppColors.errorRed)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var canSave: Bool {
        !editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !editedStoryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    /// Load config, themes, and focus tags on initial view appearance
    private func loadConfigAndData() async {
        do {
            // Load all data in parallel for better performance
            async let configTask = service.loadConfig()
            async let themesTask = service.getThemes()
            async let focusTagsTask = service.getFocusTags()

            let (config, themesResponse, _) = try await (configTask, themesTask, focusTagsTask)

            await MainActor.run {
                voices = config.voices
                selectedVoice = config.defaults.voiceId
                category = themesResponse.category

                // Preselect first focus tag if not already selected
                if !hasPreselectedFocusTag, let firstTag = service.focusTags.first {
                    selectedFocusTag = firstTag
                    hasPreselectedFocusTag = true
                }
            }

            #if DEBUG
            print("🌙 BedtimeStoriesCreateView: Loaded config, \(service.themes.count) themes, and \(service.focusTags.count) focus tags")
            print("🎯 BedtimeStoriesCreateView: Preselected focus tag: \(selectedFocusTag?.name ?? "none")")
            #endif
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                showingError = true
            }
        }
    }

    /// Reload only translated content when language changes
    private func reloadTranslatedContent() async {
        do {
            // Save currently selected focus tag ID
            let currentFocusTagId = selectedFocusTag?.id

            // Only reload themes and focus tags (backend provides translated content)
            async let themesTask = service.getThemes()
            async let focusTagsTask = service.getFocusTags()

            let (themesResponse, _) = try await (themesTask, focusTagsTask)

            await MainActor.run {
                category = themesResponse.category

                // Restore focus tag selection with updated translation
                if let tagId = currentFocusTagId {
                    selectedFocusTag = service.focusTags.first { $0.id == tagId }
                } else if !hasPreselectedFocusTag, let firstTag = service.focusTags.first {
                    // Preselect first tag if nothing was selected
                    selectedFocusTag = firstTag
                    hasPreselectedFocusTag = true
                }
            }

            #if DEBUG
            print("🌐 BedtimeStoriesCreateView: Reloaded translated content - \(service.themes.count) themes, \(service.focusTags.count) focus tags")
            print("🎯 BedtimeStoriesCreateView: Restored focus tag: \(selectedFocusTag?.name ?? "none")")
            #endif
        } catch {
            #if DEBUG
            print("❌ BedtimeStoriesCreateView: Error reloading translated content - \(error.localizedDescription)")
            #endif
        }
    }

    private func loadThemes() async {
        isLoading = true
        do {
            let response = try await service.getThemes()
            self.category = response.category
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                showingError = true
            }
        }
        isLoading = false
    }

    private func createDraft() async {
        guard let theme = selectedTheme else { return }

        isLoading = true
        do {
            let draft = try await service.createDraft(
                prompt: prompt,
                length: selectedLength,
                optionId: theme.id,
                characterName: characterName.isEmpty ? nil : characterName,
                ageGroup: ageGroup,
                focusTagId: selectedFocusTag?.id
            )
            await MainActor.run {
                currentDraft = draft
                transitionEdge = .trailing
                currentStep = 3
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                showingError = true
            }
        }
        isLoading = false
    }

    private func enterEditMode() {
        guard let draft = currentDraft else { return }
        editedTitle = draft.title
        editedStoryText = draft.storyText
        isEditMode = true
    }

    private func exitEditMode() {
        isEditMode = false
        editedTitle = ""
        editedStoryText = ""
    }

    private func saveDraft() async {
        guard let draft = currentDraft else { return }

        isLoading = true
        do {
            try await service.updateDraft(
                id: draft.id,
                storyText: editedStoryText,
                title: editedTitle
            )
            await MainActor.run {
                // Update the current draft with saved values
                currentDraft?.title = editedTitle
                currentDraft?.storyText = editedStoryText

                // Exit edit mode
                isEditMode = false
                editedTitle = ""
                editedStoryText = ""
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                showingError = true
            }
        }
        isLoading = false
    }

    private func generateStory() async {
        guard let draft = currentDraft else { return }

        Task {
            _ = try? await service.generateStory(
                draftId: draft.id,
                voiceId: selectedVoice
            )
            await tokenManager.refreshSilently()
        }
    }
}

// MARK: - Supporting Views

struct ThemeCard: View {
    let theme: BedtimeThemeOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(AppColors.primaryIndigo.opacity(0.2))
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .overlay(Text("🌙").font(.system(size: 40)))
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
            .background(AppColors.primaryIndigo.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                    .stroke(
                        isSelected ? AppColors.primaryIndigo : AppColors.primaryIndigo.opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg))
            .shadow(
                color: AppColors.primaryIndigo.opacity(isSelected ? 0.3 : 0.1),
                radius: 10,
                x: 0,
                y: 10
            )
        }
        .childSafeTouchTarget()
    }
}

struct LengthButton: View {
    let length: BedtimeStoryLength
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(length.rawValue.capitalized)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                Text(durationText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.9) : AppColors.textSecondary)
                HStack(spacing: 2) {
                    Image(systemName: "circle.inset.filled")
                        .font(.system(size: 10))
                    Text("\(length.tokenCost)")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(isSelected ? .white.opacity(0.85) : AppColors.warningOrange)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(isSelected ? AppColors.primaryIndigo : AppColors.backgroundLight)
            .cornerRadius(AppSizing.cornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                    .stroke(isSelected ? AppColors.primaryIndigo : AppColors.borderLight, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var durationText: String {
        switch length {
        case .short: return "stories.2to3.min".localized
        case .medium: return "stories.4to5.min".localized
        case .long: return "stories.6to8.min".localized
        }
    }
}
