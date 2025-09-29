import SwiftUI

/// Simplified search indicator for image thumbnails
/// Since backend handles all filtering, this now just shows a simple search match indicator
struct SearchIndicatorOverlay: View {
    let searchTerm: String
    
    init(matches: [Any] = [], searchTerm: String) {
        // Ignore the matches parameter since backend handles filtering
        self.searchTerm = searchTerm
    }
    
    var body: some View {
        if !searchTerm.isEmpty {
            VStack {
                HStack {
                    Spacer()
                    
                    // Simple search match indicator
                    searchMatchBadge
                        .padding(.top, AppSpacing.xs)
                        .padding(.trailing, AppSpacing.xs)
                }
                
                Spacer()
            }
        }
    }
    
    private var searchMatchBadge: some View {
        Image(systemName: "magnifyingglass")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 24, height: 24)
            .background(
                Circle()
                    .fill(AppColors.primaryBlue)
                    .shadow(color: AppColors.primaryBlue.opacity(0.3), radius: 2, x: 0, y: 1)
            )
    }
}

#Preview {
    ZStack {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 200, height: 200)
        
        SearchIndicatorOverlay(searchTerm: "unicorn")
    }
    .previewLayout(.sizeThatFits)
    .padding()
}