import SwiftUI

/// Simplified search result summary header component
/// Since backend handles all filtering, this now just shows basic search results info
struct SearchResultSummary: View {
    let searchTerm: String
    let totalResults: Int
    let currentPage: Int
    let totalImages: Int
    let onClearSearch: () -> Void
    
    init(
        searchTerm: String,
        totalResults: Int,
        currentPage: Int = 1,
        totalImages: Int,
        matchBreakdown: Any? = nil, // Ignore this parameter
        onClearSearch: @escaping () -> Void
    ) {
        self.searchTerm = searchTerm
        self.totalResults = totalResults
        self.currentPage = currentPage
        self.totalImages = totalImages
        self.onClearSearch = onClearSearch
    }
    
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            // Main search result header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColors.primaryBlue)
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("Search Results")
                            .font(AppTypography.titleMedium)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    
                    Text("Found \(totalResults) images for \"\(searchTerm)\"")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()

                // Clear search button
                Button(action: onClearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textSecondary)
                        .font(.system(size: 20))
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.round)
                    .fill(AppColors.surfaceLight)
                    .stroke(AppColors.primaryBlue.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SearchResultSummary(
            searchTerm: "unicorn",
            totalResults: 15,
            totalImages: 150
        ) {
            print("Clear search tapped")
        }
        
        SearchResultSummary(
            searchTerm: "cat",
            totalResults: 0,
            totalImages: 150
        ) {
            print("Clear search tapped")
        }
    }
    .padding()
}