import SwiftUI

/// Toolbar button that displays a hamburger menu icon and opens the app menu sheet
struct ToolbarMenuButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(AppColors.surfaceLight)

                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.primaryBlue)
            }
            .frame(width: 36, height: 36)
            .overlay(
                Circle()
                    .stroke(AppColors.borderLight, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("menu.button".localized)
    }
}
