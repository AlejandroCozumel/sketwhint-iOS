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
        // Left: Profile avatar + name together
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: onProfileTap) {
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

        // Right: Credits + Plan badge
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 8) {
                // Credits button (purchase more credits)
                Button(action: onCreditsTap) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("0")
                            .font(AppTypography.captionLarge)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(planBadgeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(planBadgeColor.opacity(0.1))
                    .overlay(
                        Capsule()
                            .stroke(planBadgeColor.opacity(0.3), lineWidth: 1.5)
                    )
                    .clipShape(Capsule())
                }

                if tokenManager.accountType == "free" {
                    // Free user - show upgrade button
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
                } else {
                    // Paid user - show plan badge
                    Button(action: onUpgradeTap) {
                        HStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 11, weight: .semibold))
                            Text(planBadgeText)
                                .font(AppTypography.captionLarge)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(planBadgeColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(planBadgeColor.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(planBadgeColor.opacity(0.3), lineWidth: 1.5)
                        )
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Helper Properties

    /// Extract short plan name for badge (e.g., "Pro (Yearly)" -> "PRO")
    private var planBadgeText: String {
        let planName = tokenManager.planName

        // Extract first word before parenthesis
        if let firstWord = planName.components(separatedBy: " ").first {
            return firstWord.uppercased()
        }

        return "PRO"
    }

    /// Get color for plan badge matching subscription plans view
    private var planBadgeColor: Color {
        let planName = tokenManager.planName.lowercased()

        // Match colors from SubscriptionPlansView
        if planName.contains("basic") {
            return AppColors.primaryBlue
        } else if planName.contains("pro") {
            return AppColors.primaryPurple
        } else if planName.contains("max") {
            return AppColors.primaryPink
        } else if planName.contains("business") {
            return AppColors.primaryTeal
        }

        // Default fallback
        return AppColors.primaryPurple
    }
}
