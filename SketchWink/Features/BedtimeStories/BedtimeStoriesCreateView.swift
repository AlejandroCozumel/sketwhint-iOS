import SwiftUI

struct BedtimeStoriesCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = BedtimeStoriesService.shared
    @StateObject private var tokenManager = TokenBalanceManager.shared

    @State private var currentStep = 1
    @State private var isLoading = false
    @State private var error: String?
    @State private var showingError = false
    @State private var transitionEdge: Edge = .trailing

    // Step 1: Theme
    @State private var selectedTheme: BedtimeThemeOption?
    @State private var category: BedtimeStoryCategory?

    // Step 2: Details
    @State private var prompt = ""
    @State private var selectedLength: BedtimeStoryLength = .short
    @State private var characterName = ""
    @State private var ageGroup = "3-5 years old"
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
        .navigationTitle("Create Bedtime Story")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if currentStep > 1 {
                    Button(action: {
                        transitionEdge = .leading
                        currentStep -= 1
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .foregroundColor(AppColors.primaryBlue)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(8)
                        .background(AppColors.buttonSecondary)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(AppColors.borderLight, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
        }
        .toolbarBackground(AppColors.backgroundLight, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await loadConfig()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(error ?? "An unknown error occurred")
        }
        .alert("Confirm Generation", isPresented: $showingTokenConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Generate") {
                showingGenerationAlert = true
            }
        } message: {
            Text("This will cost \(selectedLength.tokenCost) tokens to generate. Do you want to proceed?")
        }
        .alert("Generating Story", isPresented: $showingGenerationAlert) {
            Button("Dismiss") {
                Task { await generateStory() }
                dismiss()
            }
        } message: {
            Text("Your story will be generated in the background and will be available in your library in 1 to 4 minutes.")
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

            Text("Step \(currentStep) of 3")
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
                Text(category?.name ?? "Choose a Story Theme")
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
            VStack(spacing: AppSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Story Idea")
                            .font(AppTypography.titleMedium)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Describe what you'd like to happen in your bedtime story")
                            .font(AppTypography.captionLarge)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                }
                TextField("A sleepy bunny finding the perfect spot to nap...", text: $prompt, axis: .vertical)
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

            VStack(spacing: AppSpacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Character Name (Optional)")
                            .font(AppTypography.titleMedium)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Give your main character a special name")
                            .font(AppTypography.captionLarge)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                }
                TextField("Enter character name", text: $characterName)
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
                        Text("Story Length")
                            .font(AppTypography.titleMedium)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Choose how long your bedtime story should be")
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
                        Text("Narrator Voice")
                            .font(AppTypography.titleMedium)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Pick a narrator voice for the story")
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
                        Text(voices.first(where: { $0.id == selectedVoice })?.name ?? "Select a voice")
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
                        Text("Age Group")
                            .font(AppTypography.titleMedium)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Select the target age for this story")
                            .font(AppTypography.captionLarge)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                }
                Menu {
                    Button("3-5 years old") { ageGroup = "3-5 years old" }
                    Button("5-7 years old") { ageGroup = "5-7 years old" }
                    Button("7-10 years old") { ageGroup = "7-10 years old" }
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
                    Text(isLoading ? "Creating Draft..." : "Create Draft (Free)")
                }
                .font(AppTypography.titleMedium)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.buttonPadding.large.vertical)
                .background(canCreateDraft && !isLoading ? AppColors.primaryIndigo : AppColors.buttonDisabled)
                .clipShape(Capsule())
            }
            .disabled(!canCreateDraft || isLoading)
            .opacity(canCreateDraft && !isLoading ? 1.0 : 0.6)
            .childSafeTouchTarget()

            if !canCreateDraft {
                Text("Please enter a story idea")
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
                        Text("Story Title")
                            .font(AppTypography.titleMedium)
                            .foregroundColor(AppColors.textPrimary)
                        TextField("Enter story title", text: $editedTitle)
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
                        Text("Story Text")
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
                        Text(currentDraft?.title ?? "Story Preview")
                            .headlineLarge()
                            .foregroundColor(AppColors.textPrimary)

                        HStack(spacing: AppSpacing.md) {
                            Label("\(currentDraft?.wordCount ?? 0) words", systemImage: "doc.text")
                            Label("\(currentDraft?.estimatedDuration ?? 0)s", systemImage: "clock")
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
                Text("Edit")
                .font(AppTypography.titleMedium)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.primaryIndigo)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.buttonPadding.large.vertical)
                .background(AppColors.backgroundLight)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppColors.primaryIndigo, lineWidth: 2)
                )
            }
            .disabled(isLoading)
            .opacity(!isLoading ? 1.0 : 0.6)
            .childSafeTouchTarget()

            // Generate Story Button
            Button {
                showingTokenConfirmation = true
            } label: {
                Text(isLoading ? "Generating Story..." : "Generate Story")
                .font(AppTypography.titleMedium)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.buttonPadding.large.vertical)
                .background(!isLoading ? AppColors.primaryIndigo : AppColors.buttonDisabled)
                .clipShape(Capsule())
            }
            .disabled(isLoading)
            .opacity(!isLoading ? 1.0 : 0.6)
            .childSafeTouchTarget()
        }
    }

    // MARK: - Edit Mode Buttons
    private var editModeButtonsView: some View {
        VStack(spacing: AppSpacing.sm) {
            // Cancel Button
            Button {
                exitEditMode()
            } label: {
                Text("Cancel")
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
            .opacity(!isLoading ? 1.0 : 0.6)
            .childSafeTouchTarget()

            // Save Button
            Button {
                Task { await saveDraft() }
            } label: {
                Text(isLoading ? "Saving..." : "Save")
                .font(AppTypography.titleMedium)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.buttonPadding.large.vertical)
                .background(!isLoading && canSave ? AppColors.primaryIndigo : AppColors.buttonDisabled)
                .clipShape(Capsule())
            }
            .disabled(!canSave || isLoading)
            .opacity(!isLoading && canSave ? 1.0 : 0.6)
            .childSafeTouchTarget()

            if !canSave {
                Text("Title and story text cannot be empty")
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
    private func loadConfig() async {
        do {
            let config = try await service.loadConfig()
            await MainActor.run {
                voices = config.voices
                selectedVoice = config.defaults.voiceId
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                showingError = true
            }
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
                ageGroup: ageGroup
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
            try? await service.generateStory(
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
        case .short: return "2-3 min"
        case .medium: return "4-5 min"
        case .long: return "6-8 min"
        }
    }
}
