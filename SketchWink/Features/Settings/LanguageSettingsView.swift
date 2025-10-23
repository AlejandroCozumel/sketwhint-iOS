import SwiftUI

struct LanguageSettingsView: View {
    @StateObject private var localization = LocalizationManager.shared
    @StateObject private var authService = AuthService.shared
    @State private var isUpdating = false
    @State private var showSuccessMessage = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: AppSpacing.sm) {
                Text("settings.language.title".localized)
                    .font(AppTypography.headlineLarge)
                    .foregroundColor(AppColors.textPrimary)

                Text("settings.language.subtitle".localized)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, AppSpacing.xl)
            .padding(.horizontal, AppSpacing.lg)

            Spacer()
                .frame(height: AppSpacing.xl)

            // Language Options
            VStack(spacing: AppSpacing.md) {
                ForEach(AppLanguage.allCases) { language in
                    LanguageOptionButton(
                        language: language,
                        isSelected: localization.currentLanguage == language,
                        isUpdating: isUpdating
                    ) {
                        selectLanguage(language)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)

            // Success Message
            if showSuccessMessage {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.successGreen)

                    Text("settings.language.success".localized)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.successGreen)
                }
                .padding(AppSpacing.md)
                .background(AppColors.successGreen.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Error Message
            if let error = errorMessage {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(AppColors.errorRed)

                    Text(error)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.errorRed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(AppSpacing.md)
                .background(AppColors.errorRed.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.md)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()
        }
        .background(AppColors.backgroundLight)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func selectLanguage(_ language: AppLanguage) {
        // Don't do anything if already selected
        guard localization.currentLanguage != language else { return }

        // Clear previous messages
        errorMessage = nil
        showSuccessMessage = false

        Task {
            await updateLanguage(language)
        }
    }

    private func updateLanguage(_ language: AppLanguage) async {
        isUpdating = true

        do {
            // Call API to update language
            try await authService.updateUserLanguage(language.rawValue)

            // Update local language preference
            await MainActor.run {
                localization.changeLanguage(to: language)
                isUpdating = false
                showSuccessMessage = true

                // Hide success message after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showSuccessMessage = false
                    }
                }
            }

            #if DEBUG
            print("✅ Language updated successfully to: \(language.displayName)")
            #endif

        } catch {
            await MainActor.run {
                isUpdating = false
                errorMessage = error.localizedDescription

                // Hide error message after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation {
                        errorMessage = nil
                    }
                }
            }

            #if DEBUG
            print("❌ Failed to update language: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - Language Option Button
struct LanguageOptionButton: View {
    let language: AppLanguage
    let isSelected: Bool
    let isUpdating: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                // Flag
                Text(language.flag)
                    .font(.system(size: 32))

                // Language Name
                VStack(alignment: .leading, spacing: 4) {
                    Text(language.displayName)
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)

                    Text(language == .english ? "English" : "Spanish")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                // Selection Indicator or Loading
                if isUpdating && isSelected {
                    ProgressView()
                        .tint(AppColors.primaryBlue)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.primaryBlue)
                }
            }
            .padding(AppSpacing.md)
            .background(
                isSelected
                    ? AppColors.primaryBlue.opacity(0.1)
                    : AppColors.surfaceLight
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected
                            ? AppColors.primaryBlue
                            : AppColors.borderLight,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .disabled(isUpdating)
        .childSafeTouchTarget()
    }
}

// MARK: - Preview
#if DEBUG
struct LanguageSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LanguageSettingsView()
        }
    }
}
#endif
