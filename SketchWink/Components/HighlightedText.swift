import SwiftUI

/// Component for highlighting search terms in text
/// Now simplified to only do visual highlighting - all filtering is done on backend
struct HighlightedText: View {
    let text: String
    let searchTerm: String
    let font: Font
    let primaryColor: Color
    let highlightColor: Color
    
    init(
        _ text: String,
        searchTerm: String,
        font: Font = AppTypography.bodyMedium,
        primaryColor: Color = AppColors.textPrimary,
        highlightColor: Color = Color.yellow.opacity(0.3)
    ) {
        self.text = text
        self.searchTerm = searchTerm
        self.font = font
        self.primaryColor = primaryColor
        self.highlightColor = highlightColor
    }
    
    var body: some View {
        if searchTerm.isEmpty {
            // No search term, show normal text
            Text(text)
                .font(font)
                .foregroundColor(primaryColor)
        } else {
            // Simple highlighting - backend already filtered results
            highlightedTextView
        }
    }
    
    private var highlightedTextView: some View {
        Text(attributedString)
            .font(font)
    }
    
    private var attributedString: AttributedString {
        var attributedString = AttributedString(text)
        
        // Apply base styling
        attributedString.foregroundColor = primaryColor
        
        // Find and highlight search term occurrences (case-insensitive, simple substring match)
        let searchTermLower = searchTerm.lowercased()
        let textLower = text.lowercased()
        
        var searchStartIndex = textLower.startIndex
        
        while searchStartIndex < textLower.endIndex {
            if let range = textLower.range(of: searchTermLower, range: searchStartIndex..<textLower.endIndex) {
                // Convert String.Index range to AttributedString range
                let lowerBound = AttributedString.Index(range.lowerBound, within: attributedString) ?? attributedString.startIndex
                let upperBound = AttributedString.Index(range.upperBound, within: attributedString) ?? attributedString.endIndex
                
                // Apply highlight styling
                attributedString[lowerBound..<upperBound].backgroundColor = highlightColor
                attributedString[lowerBound..<upperBound].foregroundColor = primaryColor
                
                // Continue searching after this match
                searchStartIndex = range.upperBound
            } else {
                break
            }
        }
        
        return attributedString
    }
    
    // MARK: - Static Factory Methods
    
    static func caseInsensitive(
        _ text: String,
        searchTerm: String,
        font: Font = AppTypography.bodyMedium,
        primaryColor: Color = AppColors.textPrimary,
        highlightColor: Color = Color.yellow.opacity(0.3)
    ) -> HighlightedText {
        return HighlightedText(
            text,
            searchTerm: searchTerm,
            font: font,
            primaryColor: primaryColor,
            highlightColor: highlightColor
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        HighlightedText(
            "This is a sample text with unicorn in it",
            searchTerm: "unicorn",
            font: AppTypography.bodyLarge
        )
        
        HighlightedText.caseInsensitive(
            "Multiple UNICORN occurrences and unicorn again",
            searchTerm: "unicorn"
        )
        
        HighlightedText(
            "No highlight here",
            searchTerm: "",
            font: AppTypography.bodyMedium
        )
    }
    .padding()
}