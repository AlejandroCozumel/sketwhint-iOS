import SwiftUI

// Helper function for timeout
func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

struct TimeoutError: Error {
    let localizedDescription = "Operation timed out"
}

struct SimpleStoryInputView: View {
    @StateObject private var draftService = DraftService.shared
    @State private var storyTheme = ""
    @State private var isCreatingDraft = false
    @State private var createdDraft: StoryDraft? {
        didSet {
            print("📖 createdDraft changed to: \(createdDraft?.title ?? "nil")")
        }
    }
    @State private var error: Error?
    @State private var showingError = false

    let onDismiss: () -> Void
    let onDraftCreated: (StoryDraft) -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    // Header
                    headerView

                    // Story Input
                    storyInputView

                    // Create Button
                    createButtonView
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
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(error?.localizedDescription ?? "An unknown error occurred")
        }
        .dismissableFullScreenCover(isPresented: $isCreatingDraft) {
            StoryCreationProgressView {
                isCreatingDraft = false
            }
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: AppSpacing.md) {
            Text("📚")
                .font(.system(size: AppSizing.iconSizes.xxl))

            VStack(spacing: AppSpacing.xs) {
                Text("AI Story Creator")
                    .headlineLarge()
                    .foregroundColor(AppColors.textPrimary)

                Text("Tell AI what kind of story you want to create")
                    .bodyMedium()
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(AppSpacing.cardPadding.inner)
        .background(AppColors.primaryBlue.opacity(0.1))
        .cornerRadius(AppSizing.cornerRadius.md)
    }

    // MARK: - Story Input View
    private var storyInputView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("What story would you like to create?")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                TextField("Example: A brave little mouse goes on an adventure to find magical cheese in an enchanted forest", text: $storyTheme, axis: .vertical)
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
                    .lineLimit(3...8)

                Text("Describe your story idea. Be as creative as you want! (minimum 10 characters)")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)

                // Character count
                HStack {
                    Spacer()
                    Text("\(storyTheme.count) characters")
                        .font(AppTypography.captionSmall)
                        .foregroundColor(storyTheme.count >= 10 ? AppColors.successGreen : AppColors.textSecondary)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Create Button View
    private var createButtonView: some View {
        VStack(spacing: AppSpacing.sm) {
            Button("Create Story Draft") {
                print("📖 Button tapped - starting story creation")
                Task {
                    print("📖 Inside Task")
                    await createStoryDraft()
                    print("📖 createStoryDraft completed")
                }
            }
            .largeButtonStyle(backgroundColor: canCreateStory ? AppColors.primaryBlue : AppColors.buttonDisabled)
            .disabled(!canCreateStory)
            .opacity(canCreateStory ? 1.0 : 0.6)
            .childSafeTouchTarget()

            if !canCreateStory {
                Text("Please enter at least 10 characters to describe your story")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.errorRed)
                    .multilineTextAlignment(.center)
            } else {
                Text("AI will create a personalized bedtime story based on your idea")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .cardStyle()
    }

    // MARK: - Computed Properties
    private var canCreateStory: Bool {
        let trimmedTheme = storyTheme.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTheme.count >= 10
    }

    // MARK: - Methods
    private func createStoryDraft() async {
        let trimmedTheme = storyTheme.trimmingCharacters(in: .whitespacesAndNewlines)

        // Create a simple request with default values
        let request = CreateDraftRequest(
            theme: trimmedTheme,
            storyType: .bedtimeStory, // Default to bedtime story
            ageGroup: .preschool, // Default to 4-6 years
            pageCount: 6, // Default to 6 pages
            focusTags: nil,
            customFocus: nil,
            aiGenerated: true // Use AI to generate the story content
        )

        #if DEBUG
        print("📝 SimpleStoryInputView: Creating draft with theme: \(trimmedTheme)")
        #endif

        isCreatingDraft = true

        do {
            #if DEBUG
            print("📖 SimpleStoryInputView: About to call createDraft")
            #endif

            // Add timeout to see if the call is hanging
            let response = try await withTimeout(seconds: 30) {
                try await draftService.createDraft(request)
            }

            #if DEBUG
            print("📖 SimpleStoryInputView: createDraft returned successfully")
            print("📖 SimpleStoryInputView: Response has draft: \(response.draft.id)")
            #endif

            // Ensure UI updates happen on the main thread
            await MainActor.run {
                #if DEBUG
                print("📖 SimpleStoryInputView: Inside MainActor.run")
                #endif

                createdDraft = response.draft

                #if DEBUG
                print("📖 SimpleStoryInputView: Set createdDraft")
                #endif

                isCreatingDraft = false

                #if DEBUG
                print("📖 SimpleStoryInputView: Set isCreatingDraft = false")
                print("📖 Draft title: \(response.draft.title)")
                print("📖 Draft pages count: \(response.draft.storyOutline.pages.count)")
                print("📖 Setting showingDraftPreview = true")
                #endif

                // Navigate to draft detail view instead of showing sheet
                onDraftCreated(response.draft)

                #if DEBUG
                print("📖 SimpleStoryInputView: Navigating to draft detail view")
                print("📖 SimpleStoryInputView: All UI updates complete")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ SimpleStoryInputView: Caught error: \(error)")
            #endif

            await MainActor.run {
                #if DEBUG
                print("❌ SimpleStoryInputView: Inside error MainActor.run")
                #endif
                self.error = error
                isCreatingDraft = false
                showingError = true
            }
        }
    }
}

// MARK: - Progress View
struct StoryCreationProgressView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppColors.primaryBlue)

            Text("Creating your story...")
                .headlineMedium()
                .foregroundColor(AppColors.textPrimary)

            Text("AI is crafting a personalized story just for you")
                .bodyMedium()
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Cancel") {
                onDismiss()
            }
            .font(AppTypography.titleMedium)
            .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundLight)
    }
}

// MARK: - Preview
#Preview {
    SimpleStoryInputView(
        onDismiss: {
            // Dismiss action
        },
        onDraftCreated: { draft in
            // Draft created action
            print("Draft created: \(draft.title)")
        }
    )
}