//
//  iPadTopToolbar.swift
//  SketchWink
//
//  Reusable iPad toolbar for consistent navigation across tabs
//

import SwiftUI

/// Reusable iPad top toolbar that appears below the navigation bar
/// Shows profile, credits, and plan badge with consistent styling
struct iPadTopToolbar: View {
    @ObservedObject var profileService: ProfileService
    @ObservedObject var tokenManager: TokenBalanceManager

    let onProfileTap: () -> Void
    let onCreditsTap: () -> Void
    let onUpgradeTap: () -> Void

    // Configuration options
    let showProfile: Bool
    let showCredits: Bool
    let showPlanBadge: Bool

    init(
        profileService: ProfileService,
        tokenManager: TokenBalanceManager,
        onProfileTap: @escaping () -> Void,
        onCreditsTap: @escaping () -> Void,
        onUpgradeTap: @escaping () -> Void,
        showProfile: Bool = true,
        showCredits: Bool = true,
        showPlanBadge: Bool = true
    ) {
        self.profileService = profileService
        self.tokenManager = tokenManager
        self.onProfileTap = onProfileTap
        self.onCreditsTap = onCreditsTap
        self.onUpgradeTap = onUpgradeTap
        self.showProfile = showProfile
        self.showCredits = showCredits
        self.showPlanBadge = showPlanBadge
    }

    var body: some View {
        HStack(spacing: AppSpacing.lg) {
            // Profile button (left side)
            if showProfile {
                Button {
                    onProfileTap()
                } label: {
                    HStack(spacing: AppSpacing.sm) {
                        // Profile avatar
                        if let currentProfile = profileService.currentProfile {
                            Text(currentProfile.displayAvatar)
                                .font(.system(size: 24))
                                .frame(width: 40, height: 40)
                                .background(
                                    Circle()
                                        .fill(Color(hex: currentProfile.profileColor).opacity(0.2))
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color(hex: currentProfile.profileColor), lineWidth: 2)
                                )

                            Text(currentProfile.name)
                                .font(AppTypography.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(AppColors.primaryBlue)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Credits button (right side)
            if showCredits {
                Button {
                    onCreditsTap()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text(tokenManager.tokenBalance?.displayTotalTokens ?? "…")
                            .font(AppTypography.bodyMedium)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(planColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(planColor.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(planColor.opacity(0.3), lineWidth: 1.5)
                    )
                    .clipShape(Capsule())
                }
            }

            // Plan badge or upgrade button (right side)
            if showPlanBadge {
                if shouldShowUpgradeButton {
                    Button {
                        onUpgradeTap()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Upgrade")
                                .font(AppTypography.bodyMedium)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [AppColors.primaryPurple, AppColors.primaryBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: Capsule()
                        )
                        .shadow(color: AppColors.primaryPurple.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                } else if let planName = tokenManager.tokenBalance?.permissions.planName {
                    Button {
                        onUpgradeTap()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 13, weight: .semibold))
                            Text(planName.components(separatedBy: " ").first?.uppercased() ?? planName.uppercased())
                                .font(AppTypography.bodyMedium)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(planColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(planColor.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(planColor.opacity(0.3), lineWidth: 1.5)
                        )
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppSpacing.pageMargin) // pageMargins (16pt)
        .padding(.vertical, AppSpacing.md)
        .background(
            AppColors.backgroundLight
        )
        .overlay(
            Rectangle()
                .fill(AppColors.borderLight)
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    // MARK: - Helper Properties

    private var shouldShowUpgradeButton: Bool {
        guard let accountType = tokenManager.tokenBalance?.permissions.accountType else {
            return false
        }
        return accountType.lowercased() == "free"
    }

    private var planColor: Color {
        guard let planName = tokenManager.tokenBalance?.permissions.planName.lowercased() else {
            return AppColors.primaryPurple
        }

        if planName.contains("basic") {
            return AppColors.primaryBlue
        } else if planName.contains("pro") {
            return AppColors.primaryPurple
        } else if planName.contains("max") {
            return AppColors.primaryPink
        } else if planName.contains("business") {
            return AppColors.primaryTeal
        }

        return AppColors.primaryPurple
    }
}
