import SwiftUI

// MARK: - Creation Method Options
enum CreationMethod: String, CaseIterable {
    case aiAssisted = "ai_assisted"
    case manual = "manual"
    
    var displayName: String {
        switch self {
        case .aiAssisted: return "AI-Assisted Creation"
        case .manual: return "Manual Creation"
        }
    }
    
    var description: String {
        switch self {
        case .aiAssisted: return "Tell AI what you want and let it create the complete story for you"
        case .manual: return "Choose all the details yourself - story type, age group, themes, and more"
        }
    }
    
    var icon: String {
        switch self {
        case .aiAssisted: return "sparkles"
        case .manual: return "slider.horizontal.3"
        }
    }
    
    var benefits: [String] {
        switch self {
        case .aiAssisted:
            return [
                "Quick and easy",
                "AI picks perfect settings",
                "Great for beginners",
                "Surprise stories"
            ]
        case .manual:
            return [
                "Full control",
                "Choose every detail",
                "Perfect for specific needs",
                "Educational content"
            ]
        }
    }
}

struct CreationMethodSelectionView: View {
    @State private var selectedMethod: CreationMethod?
    @State private var showingAIAssisted = false
    @State private var showingManualCreation = false
    
    let productCategory: ProductCategory
    let onDismiss: () -> Void
    let onDraftCreated: (StoryDraft) -> Void
    
    init(productCategory: ProductCategory, onDismiss: @escaping () -> Void, onDraftCreated: @escaping (StoryDraft) -> Void) {
        self.productCategory = productCategory
        self.onDismiss = onDismiss
        self.onDraftCreated = onDraftCreated
        
        #if DEBUG
        print("🎯 CreationMethodSelectionView: init() called for \(productCategory.name)")
        #endif
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    // Header
                    headerView
                    
                    // Method Selection Cards
                    methodSelectionView
                    
                    // Continue Button
                    continueButtonView
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
        .sheet(isPresented: $showingAIAssisted) {
            SimpleStoryInputView(
                onDismiss: {
                    showingAIAssisted = false
                },
                onDraftCreated: { draft in
                    showingAIAssisted = false
                    onDraftCreated(draft)
                }
            )
        }
        .sheet(isPresented: $showingManualCreation) {
            StoryDraftCreationView(
                productCategory: productCategory,
                onDismiss: {
                    showingManualCreation = false
                },
                onDraftCreated: { draft in
                    showingManualCreation = false
                    onDraftCreated(draft)
                }
            )
        }
    }
    
    // MARK: - Header View
    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: AppSpacing.md) {
            Text(productCategory.icon)
                .font(.system(size: AppSizing.iconSizes.xxl))
            
            VStack(spacing: AppSpacing.xs) {
                Text("How would you like to create?")
                    .headlineLarge()
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Choose your preferred way to create your story book")
                    .bodyMedium()
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                
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
    
    // MARK: - Method Selection
    @ViewBuilder
    private var methodSelectionView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Choose Creation Method")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
            
            VStack(spacing: AppSpacing.md) {
                ForEach(CreationMethod.allCases, id: \.rawValue) { method in
                    CreationMethodCard(
                        method: method,
                        isSelected: selectedMethod == method,
                        productColor: productColor
                    ) {
                        selectedMethod = method
                    }
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Continue Button
    private var continueButtonView: some View {
        VStack(spacing: AppSpacing.sm) {
            Button("Continue") {
                guard let method = selectedMethod else { return }
                
                switch method {
                case .aiAssisted:
                    showingAIAssisted = true
                case .manual:
                    showingManualCreation = true
                }
            }
            .largeButtonStyle(backgroundColor: selectedMethod != nil ? productColor : AppColors.buttonDisabled)
            .disabled(selectedMethod == nil)
            .opacity(selectedMethod != nil ? 1.0 : 0.6)
            .childSafeTouchTarget()
            
            if selectedMethod == nil {
                Text("Please select a creation method")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Computed Properties
    private var productColor: Color {
        if !productCategory.color.isEmpty {
            return Color(hex: productCategory.color)
        }
        
        switch productCategory.productType {
        case "book": return Color(hex: "#D97706") // Amber-600
        default: return AppColors.primaryBlue
        }
    }
}

// MARK: - Creation Method Card
struct CreationMethodCard: View {
    let method: CreationMethod
    let isSelected: Bool
    let productColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                // Left: Icon
                VStack {
                    Image(systemName: method.icon)
                        .font(.system(size: 32))
                        .foregroundColor(isSelected ? .white : productColor)
                }
                .frame(width: 60)
                
                // Center: Content
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        Text(method.displayName)
                            .titleMedium()
                            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 20))
                        }
                    }
                    
                    Text(method.description)
                        .bodyMedium()
                        .foregroundColor(isSelected ? .white.opacity(0.9) : AppColors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    
                    // Benefits list
                    HStack(spacing: AppSpacing.md) {
                        ForEach(method.benefits.prefix(2), id: \.self) { benefit in
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(isSelected ? .white.opacity(0.8) : AppColors.successGreen)
                                
                                Text(benefit)
                                    .captionLarge()
                                    .foregroundColor(isSelected ? .white.opacity(0.8) : AppColors.textSecondary)
                            }
                        }
                        
                        Spacer()
                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                    .fill(isSelected ? productColor : productColor.opacity(0.05))
                    .shadow(
                        color: productColor.opacity(0.1),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                            .stroke(
                                isSelected ? productColor : productColor.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .childSafeTouchTarget()
    }
}

// MARK: - AI Assisted Creation View (Simplified)
struct AIAssistedCreationView: View {
    @StateObject private var draftService = DraftService.shared
    @State private var userPrompt = ""
    @State private var isCreating = false
    @State private var error: Error?
    @State private var showingError = false
    
    let productCategory: ProductCategory
    let onDismiss: () -> Void
    let onDraftCreated: (StoryDraft) -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    // Header
                    VStack(spacing: AppSpacing.md) {
                        Text("✨")
                            .font(.system(size: AppSizing.iconSizes.xxl))
                        
                        VStack(spacing: AppSpacing.xs) {
                            Text("AI-Assisted Creation")
                                .headlineLarge()
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("Tell AI what story you want and it will choose the perfect settings for you")
                                .bodyMedium()
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .cardStyle()
                    
                    // Simple prompt input
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("What story would you like?")
                            .font(AppTypography.headlineMedium)
                            .foregroundColor(AppColors.textPrimary)
                        
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            TextField("Example: A magical adventure with talking animals in an enchanted forest", text: $userPrompt, axis: .vertical)
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
                            
                            Text("AI will automatically choose the best story type, age group, and length")
                                .font(AppTypography.captionMedium)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .cardStyle()
                    
                    // Create button
                    VStack(spacing: AppSpacing.sm) {
                        Button(isCreating ? "Creating Story..." : "Create Story with AI") {
                            Task {
                                await createAIAssistedStory()
                            }
                        }
                        .largeButtonStyle(backgroundColor: canCreate ? AppColors.primaryBlue : AppColors.buttonDisabled)
                        .disabled(!canCreate || isCreating)
                        .opacity(canCreate && !isCreating ? 1.0 : 0.6)
                        .childSafeTouchTarget()
                        
                        if !canCreate {
                            Text("Please describe what story you want")
                                .font(AppTypography.captionMedium)
                                .foregroundColor(AppColors.errorRed)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .pageMargins()
                .padding(.vertical, AppSpacing.sectionSpacing)
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("AI Creation")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
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
    }
    
    private var canCreate: Bool {
        !userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func createAIAssistedStory() async {
        isCreating = true
        
        // AI-assisted creation uses smart defaults
        let request = CreateDraftRequest(
            theme: userPrompt.trimmingCharacters(in: .whitespacesAndNewlines),
            storyType: .adventureStory, // AI will pick the best type based on theme
            ageGroup: .preschool,       // Default to popular age group
            pageCount: 6,               // Recommended page count
            focusTags: nil,             // Let AI decide
            customFocus: "Create an engaging, age-appropriate story based on the theme",
            aiGenerated: true           // AI-assisted creation uses AI generation
        )
        
        do {
            let response = try await draftService.createDraft(request)
            await MainActor.run {
                isCreating = false
                onDraftCreated(response.draft)
            }
        } catch {
            await MainActor.run {
                self.error = error
                showingError = true
                isCreating = false
            }
        }
    }
}