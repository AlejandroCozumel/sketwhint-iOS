import SwiftUI

struct BookDraftReviewView: View {
    @StateObject private var draftService = DraftService.shared
    @State private var editedPageTexts: [String]
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var error: Error?
    @State private var showingError = false
    @State private var isGenerating = false
    @State private var showingSuccessAlert = false

    let originalDraft: StoryDraft
    let productCategory: ProductCategory
    let onDismiss: () -> Void

    init(draft: StoryDraft, productCategory: ProductCategory, onDismiss: @escaping () -> Void) {
        self.originalDraft = draft
        self.productCategory = productCategory
        self.onDismiss = onDismiss
        self._editedPageTexts = State(initialValue: draft.pageTexts)

        #if DEBUG
        print("📖 BookDraftReviewView: Initialized with draft")
        print("📖 Title: \(draft.title)")
        print("📖 Pages: \(draft.pageTexts.count)")
        #endif
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: AppSpacing.sectionSpacing) {
                        // Book Header
                        bookHeaderView

                        // Pages Review Section - Simple page-by-page text editing
                        pagesReviewSection
                    }
                    .pageMargins()
                    .padding(.vertical, AppSpacing.sectionSpacing)
                    .padding(.bottom, isEditing ? 0 : 100) // Space for bottom button
                }
                .background(AppColors.backgroundLight)

                // Sticky Continue Button at Bottom (only when not editing)
                if !isEditing {
                    continueToGenerationButton
                        .padding(.horizontal, AppSpacing.pageMargin)
                        .padding(.bottom, AppSpacing.md)
                        .background(
                            LinearGradient(
                                colors: [
                                    AppColors.backgroundLight.opacity(0),
                                    AppColors.backgroundLight
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 100)
                            .offset(y: -80)
                        )
                }
            }
            .navigationTitle(isEditing ? "Edit Pages" : "Review Story")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        onDismiss()
                    }) {
                        ZStack {
                            Circle()
                                .fill(AppColors.surfaceLight)
                            Image(systemName: "chevron.left")
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
                    .accessibilityLabel("Back")
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
        .alert("Book Generation Started", isPresented: $showingSuccessAlert) {
            Button("OK") {
                onDismiss()
            }
        } message: {
            Text("Your book is being generated in the background. This may take a few minutes. You'll find it in the Books section when ready.")
        }
    }

    // MARK: - Book Header
    private var bookHeaderView: some View {
        VStack(spacing: AppSpacing.md) {
            Text(productCategory.icon)
                .font(.system(size: AppSizing.iconSizes.xxl))

            VStack(spacing: AppSpacing.xs) {
                Text(originalDraft.title)
                    .headlineLarge()
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(originalDraft.theme)
                    .bodyMedium()
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)

                // Book Stats
                HStack(spacing: AppSpacing.md) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(productColor)
                            .font(.system(size: 12))
                        Text("\(originalDraft.pageCount) pages")
                            .captionLarge()
                            .foregroundColor(AppColors.textSecondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .foregroundColor(AppColors.primaryPurple)
                            .font(.system(size: 12))
                        Text("Age \(originalDraft.ageGroup)")
                            .captionLarge()
                            .foregroundColor(AppColors.textSecondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(AppColors.warningOrange)
                            .font(.system(size: 12))
                        Text("\(originalDraft.pageCount * 2) tokens")
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

    // MARK: - Pages Review Section - Minimal Style
    private var pagesReviewSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("Story Pages")
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.textPrimary)

                    Text("Review and edit each page")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                if !isEditing {
                    Button(action: {
                        isEditing = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: 12))
                            Text("Edit")
                                .font(AppTypography.captionMedium)
                        }
                        .foregroundColor(AppColors.primaryBlue)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                        .background(AppColors.primaryBlue.opacity(0.1))
                        .cornerRadius(AppSizing.cornerRadius.sm)
                    }
                }
            }

            // Simple page cards - just page number and text
            ForEach(Array(editedPageTexts.enumerated()), id: \.offset) { index, pageText in
                SimplePageCard(
                    pageNumber: index + 1,
                    pageText: $editedPageTexts[index],
                    isEditing: isEditing,
                    productColor: productColor
                )
            }
        }
        .cardStyle()
    }

    // MARK: - Generate Book Button (Sticky Bottom)
    private var continueToGenerationButton: some View {
        Button(action: {
            Task {
                await generateBook()
            }
        }) {
            HStack {
                if isGenerating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(isGenerating ? "Generating..." : "Generate Book")
            }
            .frame(maxWidth: .infinity)
        }
        .largeButtonStyle(backgroundColor: productColor)
        .disabled(isGenerating)
        .opacity(isGenerating ? 0.7 : 1.0)
        .childSafeTouchTarget()
    }

    // MARK: - Computed Properties
    private var currentDraft: StoryDraft {
        // Only update page texts if changed
        if hasChanges {
            return StoryDraft(
                id: originalDraft.id,
                userId: originalDraft.userId,
                familyProfileId: originalDraft.familyProfileId,
                templateId: originalDraft.templateId,
                productType: originalDraft.productType,
                title: originalDraft.title,
                theme: originalDraft.theme,
                ageGroup: originalDraft.ageGroup,
                pageCount: originalDraft.pageCount,
                focusTags: originalDraft.focusTags,
                customFocus: originalDraft.customFocus,
                aiGenerated: false, // Mark as manually edited
                storyOutline: originalDraft.storyOutline,
                pageTexts: editedPageTexts,
                characterDescriptions: originalDraft.characterDescriptions,
                artStyle: originalDraft.artStyle,
                status: originalDraft.status,
                tokensCost: originalDraft.tokensCost,
                createdAt: originalDraft.createdAt,
                updatedAt: originalDraft.updatedAt
            )
        } else {
            return originalDraft
        }
    }

    private var hasChanges: Bool {
        editedPageTexts != originalDraft.pageTexts
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
    private func cancelEditing() {
        editedPageTexts = originalDraft.pageTexts
        isEditing = false
    }

    private func saveChanges() async {
        #if DEBUG
        print("📖 BookDraftReviewView: saveChanges() called")
        print("📖 Has changes: \(hasChanges)")
        print("📖 Number of pages: \(editedPageTexts.count)")
        print("📖 Draft ID: \(originalDraft.id)")
        #endif

        guard hasChanges else {
            #if DEBUG
            print("⚠️ BookDraftReviewView: No changes detected, exiting edit mode")
            #endif
            await MainActor.run {
                isEditing = false
            }
            return
        }

        await MainActor.run {
            isSaving = true
        }

        let updates = UpdateDraftRequest(
            title: nil, // Don't update title
            pageTexts: editedPageTexts
        )

        #if DEBUG
        print("📤 BookDraftReviewView: Sending update request")
        print("📤 Page texts: \(editedPageTexts.map { "\"\($0.prefix(50))...\"" })")
        #endif

        do {
            let updatedDraft = try await draftService.updateDraft(id: originalDraft.id, updates: updates)

            #if DEBUG
            print("✅ BookDraftReviewView: Changes saved successfully")
            print("✅ Updated draft received: \(updatedDraft.title)")
            #endif

            await MainActor.run {
                isEditing = false
                isSaving = false
            }
        } catch {
            #if DEBUG
            print("❌ BookDraftReviewView: Failed to save changes")
            print("❌ Error: \(error.localizedDescription)")
            #endif

            await MainActor.run {
                self.error = error
                showingError = true
                isSaving = false
            }
        }
    }

    // MARK: - Generate Book
    private func generateBook() async {
        #if DEBUG
        print("📖 BookDraftReviewView: Generating book from draft")
        print("📖 Draft ID: \(currentDraft.id)")
        print("📖 Draft title: \(currentDraft.title)")
        #endif

        await MainActor.run {
            isGenerating = true
        }

        // Use backend defaults for quality, model, and dimensions
        let options = GenerateBookFromDraftRequest(
            model: "seedream",      // Backend default
            quality: "standard",    // Backend default
            dimensions: "a4"        // Backend default for books
        )

        do {
            let response = try await draftService.generateBookFromDraft(draftId: currentDraft.id, options: options)

            #if DEBUG
            print("✅ BookDraftReviewView: Book generation started")
            print("✅ Product ID: \(response.productId)")
            print("✅ Showing success alert and dismissing sheet")
            #endif

            await MainActor.run {
                isGenerating = false
                showingSuccessAlert = true
            }
        } catch {
            #if DEBUG
            print("❌ BookDraftReviewView: Book generation failed")
            print("❌ Error: \(error.localizedDescription)")
            #endif

            await MainActor.run {
                isGenerating = false
                self.error = error
                showingError = true
            }
        }
    }
}

// MARK: - Simple Page Card (Minimal Bedtime Story Style)
struct SimplePageCard: View {
    let pageNumber: Int
    @Binding var pageText: String
    let isEditing: Bool
    let productColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Page Number Header
            HStack {
                Text("Page \(pageNumber)")
                    .font(AppTypography.titleMedium)
                    .foregroundColor(productColor)

                Spacer()
            }

            Divider()

            // Page Text - Simple and Clean
            if isEditing {
                TextField("Page text", text: $pageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(AppTypography.bodyLarge)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(AppSpacing.md)
                    .background(AppColors.backgroundLight)
                    .cornerRadius(AppSizing.cornerRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                            .stroke(productColor.opacity(0.3), lineWidth: 1)
                    )
                    .lineLimit(3...15)
            } else {
                Text(pageText)
                    .font(AppTypography.bodyLarge)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                .fill(AppColors.backgroundLight)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                .stroke(
                    isEditing ? productColor.opacity(0.3) : AppColors.borderLight,
                    lineWidth: isEditing ? 2 : 1
                )
        )
        .shadow(
            color: Color.black.opacity(isEditing ? 0.05 : 0.02),
            radius: isEditing ? 4 : 2,
            x: 0,
            y: 1
        )
    }
}
