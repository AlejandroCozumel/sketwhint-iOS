import SwiftUI

/// Enhanced empty search state with suggestions
/// Simplified version for backend search architecture
struct EnhancedEmptySearchState: View {
    let searchTerm: String
    let suggestions: [String]
    let recentSearches: [String]
    let onSuggestionTap: (String) -> Void
    let onClearSearch: () -> Void
    
    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(AppColors.primaryBlue.opacity(0.6))
            
            VStack(spacing: AppSpacing.md) {
                Text("No Results Found")
                    .font(AppTypography.headlineLarge)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("We couldn't find any images matching \"\(searchTerm)\"")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Search suggestions
            if !suggestions.isEmpty {
                VStack(spacing: AppSpacing.md) {
                    Text("Try searching for:")
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: AppSpacing.sm) {
                        ForEach(suggestions.prefix(6), id: \.self) { suggestion in
                            Button(suggestion) {
                                onSuggestionTap(suggestion)
                            }
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.primaryBlue)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(AppColors.primaryBlue.opacity(0.1))
                                    .stroke(AppColors.primaryBlue.opacity(0.3), lineWidth: 1)
                            )
                            .childSafeTouchTarget()
                        }
                    }
                }
            }
            
            // Clear search button
            Button("Clear Search") {
                onClearSearch()
            }
            .largeButtonStyle(backgroundColor: AppColors.buttonSecondary)
            .childSafeTouchTarget()
        }
        .cardStyle()
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacing.md)
    }
}

#Preview {
    EnhancedEmptySearchState(
        searchTerm: "unicorn",
        suggestions: ["animals", "cute", "stickers", "coloring pages", "nature", "fantasy"],
        recentSearches: [],
        onSuggestionTap: { suggestion in
            print("Suggestion tapped: \(suggestion)")
        },
        onClearSearch: {
            print("Clear search tapped")
        }
    )
    .padding()
}