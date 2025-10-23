//
//  LanguagePickerView.swift
//  SketchWink
//
//  Language selection view for changing app language
//

import SwiftUI

struct LanguagePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var localization = LocalizationManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Header
                    VStack(spacing: AppSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.primaryBlue, AppColors.primaryPurple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .shadow(
                                    color: AppColors.primaryBlue.opacity(0.3),
                                    radius: AppSizing.shadows.large.radius,
                                    x: AppSizing.shadows.large.x,
                                    y: AppSizing.shadows.large.y
                                )

                            Text("🌐")
                                .font(.system(size: 50))
                        }

                        VStack(spacing: AppSpacing.sm) {
                            Text("language.selection.title".localized)
                                .headlineLarge()
                                .foregroundColor(AppColors.textPrimary)
                                .multilineTextAlignment(.center)

                            Text("language.choose.prompt".localized)
                                .bodyMedium()
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .contentPadding()

                    // Language Options
                    VStack(spacing: AppSpacing.md) {
                        ForEach(AppLanguage.allCases) { language in
                            Button(action: {
                                withAnimation {
                                    localization.changeLanguage(to: language)
                                }
                                // Dismiss after a short delay to show selection
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    dismiss()
                                }
                            }) {
                                HStack(spacing: AppSpacing.md) {
                                    // Flag emoji
                                    Text(language.flag)
                                        .font(.system(size: 40))

                                    // Language info
                                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                        Text(language.displayName)
                                            .bodyLarge()
                                            .foregroundColor(AppColors.textPrimary)
                                            .fontWeight(.semibold)

                                        Text(language.rawValue.uppercased())
                                            .captionLarge()
                                            .foregroundColor(AppColors.textSecondary)
                                    }

                                    Spacer()

                                    // Checkmark for selected language
                                    if localization.currentLanguage == language {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(AppColors.successGreen)
                                    } else {
                                        Image(systemName: "circle")
                                            .font(.system(size: 28))
                                            .foregroundColor(AppColors.borderMedium)
                                    }
                                }
                                .padding(AppSpacing.md)
                                .background(
                                    localization.currentLanguage == language
                                        ? AppColors.successGreen.opacity(0.1)
                                        : AppColors.surfaceLight
                                )
                                .cornerRadius(AppSizing.cornerRadius.lg)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                                        .stroke(
                                            localization.currentLanguage == language
                                                ? AppColors.successGreen.opacity(0.3)
                                                : AppColors.borderLight,
                                            lineWidth: localization.currentLanguage == language ? 2 : 1
                                        )
                                )
                                .shadow(
                                    color: localization.currentLanguage == language
                                        ? AppColors.successGreen.opacity(0.2)
                                        : Color.clear,
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                            }
                            .buttonStyle(.plain)
                            .childSafeTouchTarget()
                        }
                    }
                    .cardStyle()
                }
                .pageMargins()
                .padding(.vertical, AppSpacing.sectionSpacing)
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("settings.language".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(AppColors.surfaceLight)

                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(AppColors.borderLight, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("common.close".localized)
                }
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct LanguagePickerView_Previews: PreviewProvider {
    static var previews: some View {
        LanguagePickerView()
            .previewDisplayName("Language Picker")

        LanguagePickerView()
            .preferredColorScheme(.dark)
            .previewDisplayName("Language Picker (Dark)")
    }
}
#endif
