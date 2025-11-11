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
                    .padding(.bottom, 140) // Space for bottom buttons
                }
                .background(AppColors.backgroundLight)

                // Bottom Buttons (Edit/Save + Generate)
                bottomButtonsView
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
                        .frame(height: 150)
                        .offset(y: -130)
                    )
            }
            .navigationTitle("books.review.story".localized)
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
        VStack(spacing: AppSpacing.xs) {
            Text(originalDraft.title)
                .headlineLarge()
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(originalDraft.theme)
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
            .padding(.top, AppSpacing.xs)
        }
        .cardStyle()
    }

    // MARK: - Pages Review Section - Minimal Style
    private var pagesReviewSection: some View {
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
                    isEditing: isEditing,
                    productColor: productColor
                )
            }
        }
        .cardStyle()
    }

    // MARK: - Bottom Buttons (Edit/Save + Generate)
    private var bottomButtonsView: some View {
        VStack(spacing: AppSpacing.sm) {
            if isEditing {
                // Edit Mode: Cancel + Save buttons
                Button {
                    cancelEditing()
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
                .disabled(isSaving)

                Button {
                    Task {
                        await saveChanges()
                    }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(isSaving ? "books.saving".localized : "books.update".localized)
                    }
                    .largeButtonStyle(
                        backgroundColor: productColor,
                        isDisabled: isSaving
                    )
                }
                .disabled(isSaving)
            } else {
                // Review Mode: Edit + Generate buttons
                Button {
                    isEditing = true
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
                .disabled(isGenerating)

                Button {
                    Task {
                        await generateBook()
                    }
                } label: {
                    HStack {
                        if isGenerating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isGenerating ? "books.generating".localized : "books.generate.book".localized)
                    }
                    .largeButtonStyle(
                        backgroundColor: productColor,
                        isDisabled: isGenerating
                    )
                }
                .disabled(isGenerating)
            }
        }
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
                Text(String(format: "books.page.number".localized, pageNumber))
                    .font(AppTypography.titleMedium)
                    .foregroundColor(productColor)

                Spacer()
            }

            Divider()

            // Page Text - Simple and Clean
            if isEditing {
                TextField("books.page.text.placeholder".localized, text: $pageText, axis: .vertical)
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
