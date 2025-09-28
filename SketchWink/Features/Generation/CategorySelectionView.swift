import SwiftUI

struct CategorySelectionView: View {
    @StateObject private var generationService = GenerationService.shared
    @State private var categories: [CategoryWithOptions] = []
    @State private var isLoading = true
    @State private var error: Error?
    @State private var showingError = false
    @State private var selectedCategory: CategoryWithOptions?
    
    
    var body: some View {
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
        .navigationBarBackButtonHidden(false)
        .task {
            await loadCategories()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(error?.localizedDescription ?? "An unknown error occurred")
        }
        .sheet(item: $selectedCategory) { category in
            GenerationView(
                preselectedCategory: category,
                onDismiss: {
                    selectedCategory = nil
                }
            )
            .onAppear {
                #if DEBUG
                print("🎯 CategorySelection: Sheet opened with category: \(category.category.name)")
                print("🎯 CategorySelection: Options count: \(category.options.count)")
                #endif
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
            // Token Balance Display
            TokenBalanceView(showDetails: true, compact: false)
            
            Text("🎨")
                .font(.system(size: AppSizing.iconSizes.xxl))
            
            VStack(spacing: AppSpacing.sm) {
                Text("What would you like to create?")
                    .headlineLarge()
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Choose from coloring pages, stickers, wallpapers, and mandalas! Story books are in the Books tab.")
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
                        #if DEBUG
                        print("🎯 CategorySelection: Selected \(category.category.name) with \(category.options.count) options")
                        for option in category.options {
                            print("   - \(option.name)")
                        }
                        #endif
                        selectedCategory = category
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
            let allCategories = try await generationService.getCategoriesWithOptions()
            
            // Filter out story books - they are now handled by the dedicated Books tab
            categories = allCategories.filter { categoryWithOptions in
                categoryWithOptions.category.id != "story_books"
            }
            
            #if DEBUG
            print("🎨 CategorySelection: Loaded \(categories.count) visual art categories (story books excluded)")
            let filteredOut = allCategories.count - categories.count
            if filteredOut > 0 {
                print("📚 CategorySelection: Filtered out \(filteredOut) story book categories")
            }
            #endif
            
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
        if let colorHex = category.color {
            return Color(hex: colorHex)
        }
        
        // Fallback to hardcoded colors if backend doesn't provide color
        switch category.id {
        case "coloring_pages": return AppColors.coloringPagesColor
        case "stickers": return AppColors.stickersColor
        case "wallpapers": return AppColors.wallpapersColor
        case "mandalas": return AppColors.mandalasColor
        default: return AppColors.primaryBlue
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Icon/Image Section
                VStack {
                    if let imageUrl = category.imageUrl, let url = URL(string: imageUrl) {
                        // Use backend image
                        AsyncImage(url: url) { imagePhase in
                            switch imagePhase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(categoryColor.opacity(0.3), lineWidth: 2)
                                    )
                            case .failure(_), .empty:
                                // Fallback to colored circle with icon
                                Circle()
                                    .fill(categoryColor.opacity(0.2))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Text(category.icon ?? "🎨")
                                            .font(.system(size: 28))
                                    )
                            @unknown default:
                                Circle()
                                    .fill(categoryColor.opacity(0.2))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Text(category.icon ?? "🎨")
                                            .font(.system(size: 28))
                                    )
                            }
                        }
                    } else {
                        // Fallback to icon or default
                        Circle()
                            .fill(categoryColor.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text(category.icon ?? "🎨")
                                    .font(.system(size: 28))
                            )
                    }
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
            .frame(height: 200)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                    .fill(categoryColor.opacity(0.08))
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

