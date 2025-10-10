import SwiftUI

struct BedtimeStoriesCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = BedtimeStoriesService.shared
    @StateObject private var tokenManager = TokenBalanceManager.shared

    @State private var currentStep = 1
    @State private var isLoading = false
    @State private var error: String?
    @State private var showingError = false

    // Step 1: Theme & Prompt
    @State private var selectedTheme: BedtimeThemeOption?
    @State private var prompt = ""
    @State private var selectedLength: BedtimeStoryLength = .short
    @State private var characterName = ""
    @State private var ageGroup = "3-5 years old"

    // Step 2: Draft (auto-loaded)
    @State private var currentDraft: BedtimeDraft?

    // Step 3: Voice & Speed
    @State private var selectedVoice = "nova"
    @State private var selectedSpeed = 1.0
    @State private var voices: [Voice] = []
    @State private var speedOptions: [SpeedOption] = []

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            progressBar

            // Main content
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    switch currentStep {
                    case 1:
                        step1ThemeAndPrompt
                    case 2:
                        step2DraftPreview
                    case 3:
                        step3VoiceSelection
                    default:
                        EmptyView()
                    }
                }
                .padding(AppSpacing.md)
                .padding(.bottom, AppSpacing.xl)
            }
            .background(AppColors.backgroundLight)

            // Bottom navigation (only for steps 2 and 3)
            if currentStep > 1 {
                bottomNavigationBar
            }
        }
        .navigationTitle("Create Bedtime Story")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(AppColors.primaryBlue)
            }
        }
        .task {
            await loadConfig()
            await loadThemes()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(error ?? "An unknown error occurred")
        }
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        VStack(spacing: AppSpacing.xs) {
            HStack(spacing: 4) {
                ForEach(1...3, id: \.self) { step in
                    Rectangle()
                        .fill(step <= currentStep ? Color(hex: "#6366F1") : AppColors.borderLight)
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

    // MARK: - Step 1: Theme & Prompt
    private var step1ThemeAndPrompt: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            // Header
            VStack(alignment: .center, spacing: AppSpacing.md) {
                Text("Choose a Story Theme")
                    .font(AppTypography.categoryTitle)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 10)

                // Themes grid
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
                            }
                        }
                    }
                }
            }

            // Prompt Input
            if selectedTheme != nil {
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
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                                .stroke(AppColors.borderLight, lineWidth: 1)
                        )
                        .lineLimit(3...6)
                }
                .cardStyle()

                // Length selector
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
                            LengthButton(
                                length: length,
                                isSelected: selectedLength == length
                            ) {
                                selectedLength = length
                            }
                        }
                    }
                }
                .cardStyle()

                // Character name (optional)
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
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                                .stroke(AppColors.borderLight, lineWidth: 1)
                        )
                }
                .cardStyle()

                // Age group
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
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                                .stroke(AppColors.borderLight, lineWidth: 1)
                        )
                    }
                }
                .cardStyle()

                // Generate Draft Button (inline for step 1)
                createDraftButtonView
            }
        }
    }

    // MARK: - Create Draft Button
    private var createDraftButtonView: some View {
        VStack(spacing: AppSpacing.sm) {
            Button {
                Task {
                    await createDraft()
                }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.9)
                    }

                    Text(isLoading ? "Creating Draft..." : "Create Draft (Free)")
                        .font(AppTypography.titleMedium)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.lg)
                .background(canCreateDraft && !isLoading ? Color(hex: "#6366F1") : AppColors.buttonDisabled)
                .clipShape(Capsule())
            }
            .disabled(!canCreateDraft || isLoading)
            .opacity(canCreateDraft && !isLoading ? 1.0 : 0.6)
            .childSafeTouchTarget()

            if !canCreateDraft {
                Text("Please select a theme and enter a story idea")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.errorRed)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var canCreateDraft: Bool {
        selectedTheme != nil && !prompt.isEmpty
    }

    // MARK: - Step 2: Draft Preview
    private var step2DraftPreview: some View {
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

            // Story text preview
            if let draft = currentDraft {
                Text(draft.storyText)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(AppSpacing.md)
                    .background(AppColors.surfaceLight)
                    .cornerRadius(AppSizing.cornerRadius.md)
            }

            // Info card
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(AppColors.infoBlue)
                Text("Review your story. You can edit it in the next step if needed.")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(AppSpacing.md)
            .background(AppColors.infoBlue.opacity(0.1))
            .cornerRadius(AppSizing.cornerRadius.sm)
        }
    }

    // MARK: - Step 3: Voice Selection
    private var step3VoiceSelection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("Choose a Voice & Speed")
                    .headlineMedium()
                    .foregroundColor(AppColors.textPrimary)

                Text("Pick a narrator voice and reading speed")
                    .bodyMedium()
                    .foregroundColor(AppColors.textSecondary)
            }

            // Voices
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Narrator Voice")
                    .titleSmall()
                    .foregroundColor(AppColors.textSecondary)

                ForEach(voices) { voice in
                    VoiceCard(
                        voice: voice,
                        isSelected: selectedVoice == voice.id
                    ) {
                        selectedVoice = voice.id
                    }
                }
            }

            // Speed
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text("Reading Speed")
                    .titleSmall()
                    .foregroundColor(AppColors.textSecondary)

                ForEach(speedOptions) { option in
                    SpeedCard(
                        option: option,
                        isSelected: selectedSpeed == option.value
                    ) {
                        selectedSpeed = option.value
                    }
                }
            }

            // Token cost reminder
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "star.fill")
                    .foregroundColor(AppColors.warningOrange)
                Text("This will cost \(selectedLength.tokenCost) tokens to generate")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(AppSpacing.md)
            .background(AppColors.warningOrange.opacity(0.1))
            .cornerRadius(AppSizing.cornerRadius.sm)
        }
    }

    // MARK: - Bottom Navigation
    private var bottomNavigationBar: some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.md) {
                if currentStep > 1 {
                    Button("Back") {
                        currentStep -= 1
                    }
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColors.surfaceLight)
                    .cornerRadius(AppSizing.cornerRadius.sm)
                }

                Button(nextButtonTitle) {
                    Task {
                        await handleNextStep()
                    }
                }
                .font(AppTypography.titleMedium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.md)
                .background(canProceed ? Color(hex: "#6366F1") : AppColors.buttonDisabled)
                .cornerRadius(AppSizing.cornerRadius.sm)
                .disabled(!canProceed || isLoading)
                .opacity(canProceed ? 1.0 : 0.6)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.backgroundLight)
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
    }

    private var nextButtonTitle: String {
        switch currentStep {
        case 1: return "Create Draft (Free)"
        case 2: return "Choose Voice"
        case 3: return "Generate Story (\(selectedLength.tokenCost) tokens)"
        default: return "Next"
        }
    }

    private var canProceed: Bool {
        switch currentStep {
        case 1: return selectedTheme != nil && !prompt.isEmpty
        case 2: return currentDraft != nil
        case 3: return true
        default: return false
        }
    }

    // MARK: - Actions
    private func handleNextStep() async {
        switch currentStep {
        case 2:
            currentStep = 3
        case 3:
            await generateStory()
        default:
            break
        }
    }

    private func loadConfig() async {
        do {
            let config = try await service.loadConfig()
            await MainActor.run {
                voices = config.voices
                speedOptions = config.speedOptions
                selectedVoice = config.defaults.voiceId
                selectedSpeed = config.defaults.speed

                #if DEBUG
                print("🎙️ BedtimeStoriesCreateView: Config loaded")
                print("   - Voices count: \(voices.count)")
                print("   - Speed options count: \(speedOptions.count)")
                print("   - Default voice: \(selectedVoice)")
                print("   - Default speed: \(selectedSpeed)")
                for voice in voices {
                    print("     • \(voice.name) (\(voice.id)) - \(voice.description)")
                }
                for speed in speedOptions {
                    print("     • \(speed.label) (\(speed.value)) - \(speed.description)")
                }
                #endif
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                showingError = true

                #if DEBUG
                print("❌ BedtimeStoriesCreateView: Failed to load config - \(error)")
                #endif
            }
        }
    }

    private func loadThemes() async {
        isLoading = true
        do {
            _ = try await service.getThemes()
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
                currentStep = 2
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

        isLoading = true
        do {
            _ = try await service.generateStory(
                draftId: draft.id,
                voiceId: selectedVoice,
                speed: selectedSpeed
            )
            await MainActor.run {
                // Refresh token balance
                Task {
                    await tokenManager.refreshSilently()
                }
                dismiss()
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                showingError = true
            }
        }
        isLoading = false
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
                // Image section (using color as placeholder)
                Rectangle()
                    .fill(Color(hex: "#6366F1").opacity(0.2))
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .overlay(
                        Text("🌙")
                            .font(.system(size: 40))
                    )

                // Text section
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
            .background(Color(hex: "#6366F1").opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                    .stroke(
                        isSelected ? Color(hex: "#6366F1") : Color(hex: "#6366F1").opacity(0.3),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg))
            .shadow(
                color: Color(hex: "#6366F1").opacity(isSelected ? 0.3 : 0.1),
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
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                    Text("\(length.tokenCost)")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(isSelected ? .white.opacity(0.85) : AppColors.warningOrange)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(isSelected ? AppColors.primaryBlue : AppColors.backgroundLight)
            .cornerRadius(AppSizing.cornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                    .stroke(isSelected ? AppColors.primaryBlue : AppColors.borderLight, lineWidth: isSelected ? 2 : 1)
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

struct VoiceCard: View {
    let voice: Voice
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(voice.name)
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)

                    Text(voice.description)
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#6366F1"))
                        .font(.system(size: 24))
                }
            }
            .padding(AppSpacing.md)
            .background(isSelected ? Color(hex: "#6366F1").opacity(0.1) : AppColors.surfaceLight)
            .overlay(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                    .stroke(isSelected ? Color(hex: "#6366F1") : AppColors.borderLight, lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(AppSizing.cornerRadius.sm)
        }
        .childSafeTouchTarget()
    }
}

struct SpeedCard: View {
    let option: SpeedOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(option.label)
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)

                    Text(option.description)
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#6366F1"))
                        .font(.system(size: 24))
                }
            }
            .padding(AppSpacing.md)
            .background(isSelected ? Color(hex: "#6366F1").opacity(0.1) : AppColors.surfaceLight)
            .overlay(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                    .stroke(isSelected ? Color(hex: "#6366F1") : AppColors.borderLight, lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(AppSizing.cornerRadius.sm)
        }
        .childSafeTouchTarget()
    }
}
