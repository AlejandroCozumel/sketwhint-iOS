import SwiftUI

/// Language switcher button for authentication screens
/// Allows users to change app language on-the-fly before signing up/in
struct LanguageSwitcherButton: View {
    @StateObject private var localization = LocalizationManager.shared
    @State private var showLanguageMenu = false

    var body: some View {
        Button(action: {
            toggleLanguage()
        }) {
            HStack(spacing: 6) {
                Text(localization.currentLanguage.flag)
                    .font(.system(size: 16))

                Text(localization.currentLanguage.displayName)
                    .font(AppTypography.captionLarge)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .animation(.easeInOut(duration: 0.2), value: localization.currentLanguage)
    }

    /// Toggle between English and Spanish
    private func toggleLanguage() {
        let newLanguage: AppLanguage = localization.currentLanguage == .english ? .spanish : .english

        // Add haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Change language
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            localization.changeLanguage(to: newLanguage)
        }

        #if DEBUG
        print("🌍 Language switched to: \(newLanguage.displayName) (\(newLanguage.rawValue))")
        #endif
    }
}

// MARK: - Preview
#if DEBUG
struct LanguageSwitcherButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AppColors.primaryPurple
                .ignoresSafeArea()

            VStack(spacing: 20) {
                LanguageSwitcherButton()

                Text("This button toggles between English 🇺🇸 and Spanish 🇪🇸")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }
}
#endif
