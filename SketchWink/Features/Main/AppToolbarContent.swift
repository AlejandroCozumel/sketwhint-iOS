import SwiftUI

/// Reusable toolbar content for app navigation bars
/// Shows profile avatar + name on left, credits + plan badge on right
struct AppToolbarContent: ToolbarContent {
    @ObservedObject var profileService: ProfileService
    @ObservedObject var tokenManager: TokenBalanceManager

    let onProfileTap: () -> Void
    let onCreditsTap: () -> Void
    let onUpgradeTap: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            ToolbarProfileButton(profileService: profileService, onTap: onProfileTap)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            ToolbarTokenButtons(
                tokenManager: tokenManager,
                onCreditsTap: onCreditsTap,
                onUpgradeTap: onUpgradeTap
            )
        }
    }
}

// MARK: - Leading Profile Button
private struct ToolbarProfileButton: View {
    @ObservedObject var profileService: ProfileService
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if let currentProfile = profileService.currentProfile {
                    Text(currentProfile.displayAvatar)
                        .font(.system(size: 24))

                    Text(currentProfile.name)
                        .font(AppTypography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                }
            }
        }
    }
}

// MARK: - Trailing Token / Plan Buttons
private struct ToolbarTokenButtons: View {
    @ObservedObject var tokenManager: TokenBalanceManager

    let onCreditsTap: () -> Void
    let onUpgradeTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            creditsButton

            if shouldShowUpgradeButton {
                upgradeButton
            } else if let planLabel = planBadgeText {
                planBadge(planLabel)
            } else {
                placeholderBadge
            }
        }
    }

    private var creditsButton: some View {
        Button(action: onCreditsTap) {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text(creditsDisplayText)
                    .font(AppTypography.captionLarge)
                    .fontWeight(.bold)
            }
            .foregroundColor(currentPlanColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(currentPlanColor.opacity(0.1))
            .overlay(
                Capsule()
                    .stroke(currentPlanColor.opacity(0.3), lineWidth: 1.5)
            )
            .clipShape(Capsule())
        }
        .disabled(tokenManager.isLoading)
    }

    private var upgradeButton: some View {
        Button(action: onUpgradeTap) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                Text("Upgrade")
                    .font(AppTypography.captionLarge)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
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
    }

    private func planBadge(_ label: String) -> some View {
        Button(action: onUpgradeTap) {
            HStack(spacing: 4) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(AppTypography.captionLarge)
                    .fontWeight(.bold)
            }
            .foregroundColor(currentPlanColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(currentPlanColor.opacity(0.1))
            .overlay(
                Capsule()
                    .stroke(currentPlanColor.opacity(0.3), lineWidth: 1.5)
            )
            .clipShape(Capsule())
        }
    }

    private var placeholderBadge: some View {
        Capsule()
            .fill(AppColors.borderLight.opacity(0.2))
            .frame(height: 28)
            .overlay(
                Text("…")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(AppColors.textSecondary)
            )
    }

    private var currentPlanName: String? {
        tokenManager.tokenBalance?.permissions.planName
    }

    private var shouldShowUpgradeButton: Bool {
        guard let accountType = tokenManager.tokenBalance?.permissions.accountType else {
            return false
        }
        return accountType.lowercased() == "free"
    }

    private var planBadgeText: String? {
        guard let planName = currentPlanName, !planName.isEmpty else {
            return nil
        }

        if let firstWord = planName.components(separatedBy: " ").first {
            return firstWord.uppercased()
        }

        return planName.uppercased()
    }

    private var currentPlanColor: Color {
        guard let planName = currentPlanName?.lowercased() else {
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

    private var creditsDisplayText: String {
        if tokenManager.isLoading {
            return "…"
        }

        if let balance = tokenManager.tokenBalance {
            return balance.displayTotalTokens
        }

        if tokenManager.error != nil {
            return "!"
        }

        return "…"
    }
}
