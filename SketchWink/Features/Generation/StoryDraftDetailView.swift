import SwiftUI

struct StoryDraftDetailView: View {
    @StateObject private var draftService = DraftService.shared
    @State private var editedTitle: String
    @State private var editedPageTexts: [String]
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var error: Error?
    @State private var showingError = false

    let originalDraft: StoryDraft
    let onDismiss: () -> Void

    init(draft: StoryDraft, onDismiss: @escaping () -> Void) {
        self.originalDraft = draft
        self.onDismiss = onDismiss
        self._editedTitle = State(initialValue: draft.title)
        self._editedPageTexts = State(initialValue: draft.storyOutline.pages.map { $0.text })

        #if DEBUG
        print("📖 StoryDraftDetailView: Initialized with draft")
        print("📖 Title: \(draft.title)")
        print("📖 Theme: \(draft.theme)")
        print("📖 Pages: \(draft.storyOutline.pages.count)")
        print("📖 Characters: \(draft.characterDescriptions.keys.joined(separator: ", "))")
        #endif
    }

    var body: some View {
        #if DEBUG
        let _ = print("📖 StoryDraftDetailView: body rendering")
        #endif

        return NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    // Story Header
                    storyHeaderView

                    // Story Overview
                    storyOverviewView

                    // Characters Section
                    charactersSection

                    // Pages Section
                    pagesSection

                    // Action Buttons
                    actionButtonsView
                }
                .pageMargins()
                .padding(.vertical, AppSpacing.sectionSpacing)
            }
            .background(AppColors.backgroundLight)
            .navigationTitle(isEditing ? "Edit Story" : "Story Preview")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        onDismiss()
                    }
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        HStack(spacing: AppSpacing.sm) {
                            Button("Cancel") {
                                cancelEditing()
                            }
                            .font(AppTypography.titleMedium)
                            .foregroundColor(AppColors.textSecondary)

                            Button("Save") {
                                Task {
                                    await saveChanges()
                                }
                            }
                            .font(AppTypography.titleMedium)
                            .foregroundColor(AppColors.primaryBlue)
                            .disabled(isSaving)
                        }
                    } else {
                        Button("Edit") {
                            isEditing = true
                        }
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.primaryBlue)
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(error?.localizedDescription ?? "An unknown error occurred")
        }
    }

    // MARK: - Story Header
    private var storyHeaderView: some View {
        VStack(spacing: AppSpacing.md) {
            Text("📚")
                .font(.system(size: AppSizing.iconSizes.xxl))

            VStack(spacing: AppSpacing.xs) {
                if isEditing {
                    TextField("Story title", text: $editedTitle, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(AppTypography.headlineLarge)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(AppSpacing.sm)
                        .background(AppColors.backgroundLight)
                        .cornerRadius(AppSizing.cornerRadius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                .stroke(AppColors.primaryBlue.opacity(0.3), lineWidth: 1)
                        )
                } else {
                    Text(editedTitle)
                        .headlineLarge()
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                }

                Text("Theme: \(originalDraft.theme)")
                    .bodyMedium()
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)

                // Story Stats
                HStack(spacing: AppSpacing.md) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(AppColors.primaryBlue)
                            .font(.system(size: 12))
                        Text("\(originalDraft.storyOutline.pages.count) pages")
                            .captionLarge()
                            .foregroundColor(AppColors.textSecondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(AppColors.primaryPurple)
                            .font(.system(size: 12))
                        Text("\(originalDraft.characterDescriptions.count) characters")
                            .captionLarge()
                            .foregroundColor(AppColors.textSecondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(AppColors.warningOrange)
                            .font(.system(size: 12))
                        Text("\(originalDraft.tokensCost) tokens")
                            .captionLarge()
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .padding(AppSpacing.cardPadding.inner)
        .background(AppColors.primaryBlue.opacity(0.1))
        .cornerRadius(AppSizing.cornerRadius.md)
    }

    // MARK: - Story Overview
    private var storyOverviewView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Story Overview")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                DraftInfoRow(label: "Title", value: currentDraft.title)
                DraftInfoRow(label: "Main Characters", value: originalDraft.storyOutline.mainCharacters.joined(separator: ", "))
                DraftInfoRow(label: "Setting", value: originalDraft.storyOutline.setting)
                DraftInfoRow(label: "Theme", value: originalDraft.storyOutline.theme)
                DraftInfoRow(label: "Moral Lesson", value: originalDraft.storyOutline.moralLesson)
                DraftInfoRow(label: "Status", value: originalDraft.status.capitalized)
                DraftInfoRow(label: "Created", value: formatDate(originalDraft.createdAt))
            }
        }
        .cardStyle()
    }

    // MARK: - Characters Section
    private var charactersSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Characters")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)

            ForEach(Array(originalDraft.characterDescriptions.keys.sorted()), id: \.self) { characterName in
                if let character = originalDraft.characterDescriptions[characterName] {
                    CharacterCard(name: characterName, description: character)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Pages Section
    private var pagesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                Text("Story Pages")
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                if !isEditing {
                    Button("Edit Text") {
                        isEditing = true
                    }
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.primaryBlue)
                }
            }

            ForEach(Array(originalDraft.storyOutline.pages.enumerated()), id: \.element.id) { index, page in
                StoryPageCard(
                    page: page,
                    editedText: $editedPageTexts[index],
                    isEditing: isEditing
                )
            }
        }
        .cardStyle()
    }

    // MARK: - Action Buttons
    private var actionButtonsView: some View {
        VStack(spacing: AppSpacing.md) {
            if !isEditing {
                Button("Generate Illustrated Book") {
                    Task {
                        await generateBookWithDefaults()
                    }
                }
                .largeButtonStyle(backgroundColor: AppColors.primaryBlue)
                .childSafeTouchTarget()

                Button("Regenerate Story") {
                    Task {
                        await regenerateStory()
                    }
                }
                .font(AppTypography.titleMedium)
                .foregroundColor(AppColors.textSecondary)
                .childSafeTouchTarget()
            }
        }
    }

    // MARK: - Computed Properties
    private var currentDraft: StoryDraft {
        // Create updated draft with edited content
        let updatedPages = originalDraft.storyOutline.pages.enumerated().map { index, page in
            StoryPage(
                pageNumber: page.pageNumber,
                title: page.title,
                text: editedPageTexts[index],
                sceneDescription: page.sceneDescription,
                characters: page.characters
            )
        }

        let updatedOutline = StoryOutline(
            title: editedTitle,
            mainCharacters: originalDraft.storyOutline.mainCharacters,
            setting: originalDraft.storyOutline.setting,
            theme: originalDraft.storyOutline.theme,
            moralLesson: originalDraft.storyOutline.moralLesson,
            pages: updatedPages
        )

        return StoryDraft(
            id: originalDraft.id,
            userId: originalDraft.userId,
            familyProfileId: originalDraft.familyProfileId,
            templateId: originalDraft.templateId,
            productType: originalDraft.productType,
            title: editedTitle,
            theme: originalDraft.theme,
            ageGroup: originalDraft.ageGroup,
            pageCount: originalDraft.pageCount,
            focusTags: originalDraft.focusTags,
            customFocus: originalDraft.customFocus,
            aiGenerated: originalDraft.aiGenerated,
            storyOutline: updatedOutline,
            pageTexts: editedPageTexts,
            characterDescriptions: originalDraft.characterDescriptions,
            artStyle: originalDraft.artStyle,
            status: originalDraft.status,
            tokensCost: originalDraft.tokensCost,
            createdAt: originalDraft.createdAt,
            updatedAt: originalDraft.updatedAt
        )
    }

    private var hasChanges: Bool {
        editedTitle != originalDraft.title ||
        editedPageTexts != originalDraft.storyOutline.pages.map { $0.text }
    }

    // MARK: - Methods
    private func cancelEditing() {
        editedTitle = originalDraft.title
        editedPageTexts = originalDraft.storyOutline.pages.map { $0.text }
        isEditing = false
    }

    private func saveChanges() async {
        guard hasChanges else {
            isEditing = false
            return
        }

        isSaving = true

        let updates = UpdateDraftRequest(
            title: editedTitle != originalDraft.title ? editedTitle : nil,
            pageTexts: editedPageTexts != originalDraft.storyOutline.pages.map { $0.text } ? editedPageTexts : nil
        )

        do {
            _ = try await draftService.updateDraft(id: originalDraft.id, updates: updates)
            isEditing = false
            isSaving = false
        } catch {
            self.error = error
            showingError = true
            isSaving = false
        }
    }

    private func regenerateStory() async {
        do {
            _ = try await draftService.regenerateDraft(id: originalDraft.id)
            // Note: In a real app, we'd update the UI with the new content
            // For now, just dismiss since backend endpoints aren't implemented
            onDismiss()
        } catch {
            self.error = error
            showingError = true
        }
    }

    private func generateBookWithDefaults() async {
        #if DEBUG
        print("📖 StoryDraftDetailView: Generating book with default settings")
        #endif

        // Use default values for book generation
        let request = GenerateBookFromDraftRequest(
            model: "seedream",           // Default model
            quality: "standard",        // Default quality
            dimensions: "a4"           // Default dimensions
        )

        do {
            let response = try await draftService.generateBookFromDraft(draftId: currentDraft.id, options: request)

            #if DEBUG
            print("📖 StoryDraftDetailView: Book generation started with ID: \(response.productId)")
            #endif

            await MainActor.run {
                // Navigate back or show success message
                onDismiss()
            }
        } catch {
            #if DEBUG
            print("❌ StoryDraftDetailView: Book generation failed: \(error)")
            #endif

            await MainActor.run {
                self.error = error
                showingError = true
            }
        }
    }

    private func formatDate(_ dateString: String) -> String {
        // Simple date formatting - could be improved
        return dateString.components(separatedBy: "T").first ?? dateString
    }
}

// MARK: - Supporting Views

struct DraftInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(AppTypography.captionMedium)
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.leading)

            Spacer()
        }
    }
}

struct CharacterCard: View {
    let name: String
    let description: CharacterDescription

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(name)
                .font(AppTypography.titleMedium)
                .foregroundColor(AppColors.primaryBlue)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                if !description.physicalAppearance.isEmpty {
                    Text("Appearance:")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)

                    Text(description.physicalAppearance.joined(separator: ", "))
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                }

                if !description.personalityTraits.isEmpty {
                    Text("Personality:")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)

                    Text(description.personalityTraits.joined(separator: ", "))
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                }

                if !description.roleInStory.isEmpty {
                    Text("Role in Story:")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)

                    Text(description.roleInStory)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                }
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.primaryBlue.opacity(0.05))
        .cornerRadius(AppSizing.cornerRadius.sm)
    }
}

struct StoryPageCard: View {
    let page: StoryPage
    @Binding var editedText: String
    let isEditing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Page Header
            HStack {
                Text("Page \(page.pageNumber)")
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.primaryBlue)

                Spacer()

                if !page.characters.isEmpty {
                    Text("Characters: \(page.characters.joined(separator: ", "))")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            if !page.title.isEmpty {
                Text(page.title)
                    .font(AppTypography.titleSmall)
                    .foregroundColor(AppColors.textPrimary)
            }

            // Page Text (Editable)
            if isEditing {
                TextField("Page text", text: $editedText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(AppSpacing.sm)
                    .background(AppColors.backgroundLight)
                    .cornerRadius(AppSizing.cornerRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                            .stroke(AppColors.primaryBlue.opacity(0.3), lineWidth: 1)
                    )
                    .lineLimit(3...10)
            } else {
                Text(editedText)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
            }

            // Scene Description for Illustration
            if !page.sceneDescription.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Scene for Illustration:")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)

                    Text(page.sceneDescription)
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                        .italic()
                }
                .padding(AppSpacing.xs)
                .background(AppColors.primaryPurple.opacity(0.05))
                .cornerRadius(AppSizing.cornerRadius.xs)
            }
        }
        .padding(AppSpacing.sm)
        .background(AppColors.backgroundLight)
        .cornerRadius(AppSizing.cornerRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                .stroke(AppColors.borderLight, lineWidth: 1)
        )
    }
}

// MARK: - Book Generation Options Sheet
struct BookGenerationOptionsView: View {
    let draft: StoryDraft
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            Text("Book generation options coming soon...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.backgroundLight)
                .navigationTitle("Generate Book")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Close") {
                            onDismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Preview
#Preview {
    let samplePages = [
        StoryPage(pageNumber: 1, title: "The Beginning", text: "Once upon a time, in a magical forest...", sceneDescription: "A peaceful forest with tall trees and dancing fireflies", characters: ["Emma", "Forest Animals"]),
        StoryPage(pageNumber: 2, title: "The Adventure", text: "Emma discovered a hidden path...", sceneDescription: "Emma walking on a mysterious glowing path", characters: ["Emma"])
    ]

    let sampleOutline = StoryOutline(
        title: "Emma's Forest Adventure",
        mainCharacters: ["Emma", "Forest Animals"],
        setting: "A magical forest with tall trees and sparkling streams",
        theme: "Courage and friendship in nature",
        moralLesson: "Being brave and kind leads to wonderful adventures",
        pages: samplePages
    )

    // Create sample characters using a simple approach for preview
    let sampleCharacters: [String: CharacterDescription] = [:]

    let sampleDraft = StoryDraft(
        id: "1",
        userId: "sample-user",
        familyProfileId: nil,
        templateId: nil,
        productType: "adventure_story",
        title: "Emma's Forest Adventure",
        theme: "A young girl explores a magical forest",
        ageGroup: "4-6",
        pageCount: 6,
        focusTags: [],
        customFocus: nil,
        aiGenerated: true,
        storyOutline: sampleOutline,
        pageTexts: samplePages.map { $0.text },
        characterDescriptions: sampleCharacters,
        artStyle: "children_book",
        status: "completed",
        tokensCost: 5,
        createdAt: "2025-01-23T10:00:00Z",
        updatedAt: "2025-01-23T10:00:00Z"
    )

    StoryDraftDetailView(draft: sampleDraft) {
        // Dismiss
    }
}