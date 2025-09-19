import SwiftUI

struct CategorySelectionView: View {
    @StateObject private var generationService = GenerationService.shared
    @State private var categories: [CategoryWithOptions] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var showingError = false
    @State private var selectedCategory: CategoryWithOptions?
    @State private var showingGenerationView = false
    
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    
                    if isLoading {
                        loadingView
                    } else {
                        // Header
                        headerView
                        
                        // Categories Grid
                        categoriesGridView
                    }
                }
                .pageMargins()
                .padding(.vertical, AppSpacing.sectionSpacing)
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("Create Art")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.primaryBlue)
                }
            }
        }
        .task {
            await loadCategories()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(error?.localizedDescription ?? "An unknown error occurred")
        }
        .sheet(isPresented: $showingGenerationView) {
            if let selectedCategory = selectedCategory {
                GenerationView(
                    preselectedCategory: selectedCategory,
                    onDismiss: {
                        showingGenerationView = false
                        self.selectedCategory = nil
                    }
                )
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: AppSpacing.xl) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppColors.primaryBlue)
            
            Text("Loading creative options...")
                .font(AppTypography.bodyLarge)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 200)
    }
    
    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("🎨")
                .font(.system(size: AppSizing.iconSizes.xxl))
            
            VStack(spacing: AppSpacing.sm) {
                Text("What would you like to create?")
                    .headlineLarge()
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Choose from coloring pages, stickers, wallpapers, and more!")
                    .bodyMedium()
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .cardStyle()
    }
    
    // MARK: - Categories Grid
    private var categoriesGridView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Creative Categories")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
            
            LazyVGrid(columns: GridLayouts.categoryGrid, spacing: AppSpacing.grid.itemSpacing) {
                ForEach(categories) { category in
                    CategoryCard(category: category.category) {
                        selectedCategory = category
                        showingGenerationView = true
                    }
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Methods
    private func loadCategories() async {
        isLoading = true
        
        do {
            categories = try await generationService.getCategoriesWithOptions()
        } catch {
            self.error = error
            showingError = true
        }
        
        isLoading = false
    }
}

// MARK: - Category Card
struct CategoryCard: View {
    let category: GenerationCategory
    let action: () -> Void
    
    private var categoryColor: Color {
        switch category.id {
        case "coloring_pages":
            return AppColors.coloringPagesColor
        case "stickers":
            return AppColors.stickersColor
        case "wallpapers":
            return AppColors.wallpapersColor
        case "mandalas":
            return AppColors.mandalasColor
        default:
            return AppColors.primaryBlue
        }
    }
    
    private var categoryIcon: String {
        switch category.id {
        case "coloring_pages":
            return "🎨"
        case "stickers":
            return "✨"
        case "wallpapers":
            return "🖼️"
        case "mandalas":
            return "🌸"
        default:
            return "🎨"
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Icon Section
                VStack {
                    Circle()
                        .fill(categoryColor.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Text(categoryIcon)
                                .font(.system(size: 28))
                        )
                }
                .frame(height: 80)
                
                // Title Section
                VStack {
                    Text(category.name)
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 44)
                
                // Description Section
                VStack {
                    Text(category.description)
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 54)
                
                Spacer()
            }
            .padding(AppSpacing.md)
            .frame(width: .infinity, height: 200)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                    .fill(AppColors.backgroundLight)
                    .shadow(
                        color: categoryColor.opacity(0.1),
                        radius: 10,
                        x: 0,
                        y: 5
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                            .stroke(categoryColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .childSafeTouchTarget()
    }
}

