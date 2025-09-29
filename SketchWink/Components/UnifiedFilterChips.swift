import SwiftUI

// MARK: - Unified Filter Chips Component
/// Consistent filter chips design used across Books, Gallery, and other filtered views
struct UnifiedFilterChips: View {
    let config: FilterConfig
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                
                // All/Favorites Toggle (if enabled)
                if config.showFavoritesToggle {
                    favoritesToggleSection
                    filterSeparator
                }
                
                // Profile Filters (if enabled and conditions met)
                if config.showProfileFilters && shouldShowProfileFilters {
                    profileFiltersSection
                    filterSeparator
                }
                
                // Category Filters (if enabled)
                if config.showCategoryFilters {
                    categoryFiltersSection
                }
                
                // Search Toggle (if enabled)
                if config.showSearchToggle {
                    filterSeparator
                    searchToggleSection
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
        .padding(.bottom, AppSpacing.sm)
    }
    
    // MARK: - Favorites Toggle Section
    private var favoritesToggleSection: some View {
        HStack(spacing: AppSpacing.xs) {
            FilterChip(
                title: "All",
                icon: "square.grid.2x2",
                isSelected: !config.showFavoritesOnly,
                action: {
                    config.onFavoritesToggle(false)
                }
            )
            
            FilterChip(
                title: "Favorites",
                icon: "heart.fill",
                isSelected: config.showFavoritesOnly,
                action: {
                    config.onFavoritesToggle(true)
                }
            )
        }
    }
    
    // MARK: - Profile Filters Section
    private var profileFiltersSection: some View {
        HStack(spacing: AppSpacing.xs) {
            // All Profiles chip
            FilterChip(
                title: "All Profiles",
                icon: "person.2.fill",
                isSelected: config.selectedProfileFilter == nil,
                action: {
                    config.onProfileFilterChange(nil)
                }
            )
            
            // Individual profile chips
            ForEach(config.availableProfiles) { profile in
                FilterChip(
                    title: profile.name,
                    icon: profile.avatar ?? "person.circle.fill",
                    isSelected: config.selectedProfileFilter == profile.id,
                    action: {
                        config.onProfileFilterChange(profile.id)
                    }
                )
            }
        }
    }
    
    // MARK: - Category Filters Section  
    private var categoryFiltersSection: some View {
        HStack(spacing: AppSpacing.xs) {
            ForEach(config.availableCategories) { category in
                CategoryFilterChip(
                    category: category,
                    isSelected: config.selectedCategory == category.id,
                    action: {
                        let newSelection = config.selectedCategory == category.id ? nil : category.id
                        config.onCategoryFilterChange(newSelection)
                    }
                )
            }
        }
    }
    
    // MARK: - Search Toggle Section
    private var searchToggleSection: some View {
        FilterChip(
            title: config.isSearchActive ? "Hide Search" : "Search",
            icon: config.isSearchActive ? "xmark.circle" : "magnifyingglass",
            isSelected: config.isSearchActive,
            action: {
                config.onSearchToggle()
            }
        )
    }
    
    // MARK: - Helpers
    private var shouldShowProfileFilters: Bool {
        config.profileService.availableProfiles.count > 1 && 
        config.profileService.currentProfile?.isDefault == true
    }
    
    private var filterSeparator: some View {
        Rectangle()
            .fill(AppColors.borderLight)
            .frame(width: 1, height: 24)
            .padding(.horizontal, AppSpacing.xs)
    }
}

// MARK: - Filter Configuration
struct FilterConfig {
    // Services
    let profileService: ProfileService
    
    // State bindings  
    let showFavoritesOnly: Bool
    let selectedProfileFilter: String?
    let selectedCategory: String?
    let isSearchActive: Bool
    
    // Data
    let availableProfiles: [FamilyProfile]
    let availableCategories: [FilterCategory]
    
    // Feature flags
    let showFavoritesToggle: Bool
    let showProfileFilters: Bool
    let showCategoryFilters: Bool  
    let showSearchToggle: Bool
    
    // Actions
    let onFavoritesToggle: (Bool) -> Void
    let onProfileFilterChange: (String?) -> Void
    let onCategoryFilterChange: (String?) -> Void
    let onSearchToggle: () -> Void
}

// MARK: - Category Filter Chip
struct CategoryFilterChip: View {
    let category: FilterCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                // Category icon or emoji
                if let icon = category.icon {
                    if icon.count == 1 {
                        // Emoji
                        Text(icon)
                            .font(.system(size: 14))
                    } else {
                        // System icon
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                
                Text(category.name)
                    .font(AppTypography.captionLarge)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                isSelected ? (category.color ?? AppColors.primaryBlue) : Color.clear,
                in: Capsule()
            )
            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.clear : (category.color?.opacity(0.3) ?? AppColors.borderMedium),
                        lineWidth: 1.5
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .shadow(
                color: isSelected ? (category.color?.opacity(0.3) ?? AppColors.primaryBlue.opacity(0.3)) : Color.clear,
                radius: isSelected ? 4 : 0,
                x: 0,
                y: 2
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .childSafeTouchTarget()
    }
}

// MARK: - Basic Filter Chip Component
struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                
                Text(title)
                    .font(AppTypography.captionLarge)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                isSelected ? AppColors.primaryBlue : Color.clear,
                in: Capsule()
            )
            .foregroundColor(isSelected ? .white : AppColors.textPrimary)
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? Color.clear : AppColors.borderMedium,
                        lineWidth: 1
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .childSafeTouchTarget()
    }
}

// MARK: - Filter Models
struct FilterCategory: Identifiable {
    let id: String
    let name: String
    let icon: String?
    let color: Color?
}

// MARK: - Extensions for Easy Configuration
extension FilterConfig {
    
    // Gallery-specific configuration
    static func gallery(
        profileService: ProfileService,
        showFavoritesOnly: Bool,
        selectedProfileFilter: String?,
        selectedCategory: String?,
        isSearchActive: Bool,
        availableCategories: [FilterCategory],
        onFavoritesToggle: @escaping (Bool) -> Void,
        onProfileFilterChange: @escaping (String?) -> Void,
        onCategoryFilterChange: @escaping (String?) -> Void,
        onSearchToggle: @escaping () -> Void
    ) -> FilterConfig {
        FilterConfig(
            profileService: profileService,
            showFavoritesOnly: showFavoritesOnly,
            selectedProfileFilter: selectedProfileFilter,
            selectedCategory: selectedCategory,
            isSearchActive: isSearchActive,
            availableProfiles: profileService.availableProfiles,
            availableCategories: availableCategories,
            showFavoritesToggle: true,
            showProfileFilters: true,
            showCategoryFilters: true,
            showSearchToggle: true,
            onFavoritesToggle: onFavoritesToggle,
            onProfileFilterChange: onProfileFilterChange,
            onCategoryFilterChange: onCategoryFilterChange,
            onSearchToggle: onSearchToggle
        )
    }
    
    // Books-specific configuration
    static func books(
        profileService: ProfileService,
        showFavoritesOnly: Bool,
        selectedProfileFilter: String?,
        onFavoritesToggle: @escaping (Bool) -> Void,
        onProfileFilterChange: @escaping (String?) -> Void
    ) -> FilterConfig {
        FilterConfig(
            profileService: profileService,
            showFavoritesOnly: showFavoritesOnly,
            selectedProfileFilter: selectedProfileFilter,
            selectedCategory: nil,
            isSearchActive: false,
            availableProfiles: profileService.availableProfiles,
            availableCategories: [],
            showFavoritesToggle: true,
            showProfileFilters: true,
            showCategoryFilters: false,
            showSearchToggle: false,
            onFavoritesToggle: onFavoritesToggle,
            onProfileFilterChange: onProfileFilterChange,
            onCategoryFilterChange: { _ in },
            onSearchToggle: { }
        )
    }
}

// MARK: - Preview
#if DEBUG
struct UnifiedFilterChips_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppSpacing.lg) {
            // Gallery style filters
            UnifiedFilterChips(
                config: .gallery(
                    profileService: ProfileService.shared,
                    showFavoritesOnly: false,
                    selectedProfileFilter: nil,
                    selectedCategory: nil,
                    isSearchActive: false,
                    availableCategories: [
                        FilterCategory(id: "coloring", name: "Coloring", icon: "🎨", color: AppColors.coloringPagesColor),
                        FilterCategory(id: "stickers", name: "Stickers", icon: "star.fill", color: AppColors.stickersColor)
                    ],
                    onFavoritesToggle: { _ in },
                    onProfileFilterChange: { _ in },
                    onCategoryFilterChange: { _ in },
                    onSearchToggle: { }
                )
            )
            .previewDisplayName("Gallery Filters")
            
            // Books style filters
            UnifiedFilterChips(
                config: .books(
                    profileService: ProfileService.shared,
                    showFavoritesOnly: true,
                    selectedProfileFilter: nil,
                    onFavoritesToggle: { _ in },
                    onProfileFilterChange: { _ in }
                )
            )
            .previewDisplayName("Books Filters")
        }
        .padding()
        .background(AppColors.backgroundLight)
    }
}
#endif