import SwiftUI

// MARK: - Basic Detail Row (No Highlighting, No Copy)
struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .font(AppTypography.titleSmall)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Detail Row with Search Highlighting (No Copy)
struct DetailRowHighlighted: View {
    let label: String
    let value: String
    let searchTerm: String

    var body: some View {
        HStack {
            Text(label + ":")
                .font(AppTypography.titleSmall)
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            HighlightedText.caseInsensitive(
                value,
                searchTerm: searchTerm,
                font: AppTypography.bodyMedium,
                primaryColor: AppColors.textPrimary
            )
            .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Copyable Detail Row (No Highlighting)
struct CopyableDetailRow: View {
    let label: String
    let value: String
    let onCopy: (String) -> Void
    let lineLimit: Int? // Optional line limit for display (nil = unlimited)
    @State private var isPressed = false

    init(label: String, value: String, onCopy: @escaping (String) -> Void, lineLimit: Int? = nil) {
        self.label = label
        self.value = value
        self.onCopy = onCopy
        self.lineLimit = lineLimit
    }

    var body: some View {
        Button(action: {
            // Always copy the FULL value, regardless of display truncation
            UIPasteboard.general.string = value
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            onCopy(value)
        }) {
            HStack {
                Text(label + ":")
                    .font(AppTypography.titleSmall)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                HStack(spacing: AppSpacing.xs) {
                    Text(value)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(lineLimit)  // Truncate display based on lineLimit

                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.primaryBlue.opacity(0.6))
                        .alignmentGuide(.top) { d in d[.top] }
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }
    }
}

// MARK: - Copyable Detail Row with Search Highlighting (Full Featured)
struct CopyableDetailRowHighlighted: View {
    let label: String
    let value: String
    let searchTerm: String
    let onCopy: (String) -> Void
    let lineLimit: Int? // Optional line limit for display (nil = unlimited)
    @State private var isPressed = false

    init(label: String, value: String, searchTerm: String, onCopy: @escaping (String) -> Void, lineLimit: Int? = nil) {
        self.label = label
        self.value = value
        self.searchTerm = searchTerm
        self.onCopy = onCopy
        self.lineLimit = lineLimit
    }

    var body: some View {
        Button(action: {
            // Always copy the FULL value, regardless of display truncation
            UIPasteboard.general.string = value

            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            // Trigger callback for toast
            onCopy(value)
        }) {
            HStack {
                Text(label + ":")
                    .font(AppTypography.titleSmall)
                    .foregroundColor(AppColors.textSecondary)

                Spacer()

                HStack(spacing: AppSpacing.xs) {
                    HighlightedText.caseInsensitive(
                        value,
                        searchTerm: searchTerm,
                        font: AppTypography.bodyMedium,
                        primaryColor: AppColors.textPrimary
                    )
                    .multilineTextAlignment(.trailing)
                    .lineLimit(lineLimit)  // Truncate display based on lineLimit

                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.primaryBlue.opacity(0.6))
                        .alignmentGuide(.top) { d in d[.top] }
                }
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: AppSpacing.md) {
        // Basic DetailRow
        DetailRow(label: "Category", value: "Stickers")

        // DetailRow with highlighting
        DetailRowHighlighted(
            label: "Title",
            value: "Cute cat playing with yarn",
            searchTerm: "cat"
        )

        // Copyable DetailRow (no highlighting)
        CopyableDetailRow(
            label: "Prompt",
            value: "A cute cat in the garden",
            onCopy: { _ in print("Copied!") }
        )

        // Copyable DetailRow with highlighting
        CopyableDetailRowHighlighted(
            label: "Title",
            value: "Cute dog on the beach",
            searchTerm: "dog",
            onCopy: { _ in print("Copied!") }
        )
    }
    .padding()
    .background(AppColors.backgroundLight)
}
