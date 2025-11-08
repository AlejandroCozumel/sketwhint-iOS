import SwiftUI

/// Unified iPad-only tab header that mirrors the Art tab layout.
/// Renders the profile/credits toolbar plus the large title row with optional trailing actions.
struct iPadTabHeader<Actions: View>: View {
    @ObservedObject var profileService: ProfileService
    @ObservedObject var tokenManager: TokenBalanceManager

    let title: String
    let onProfileTap: () -> Void
    let onCreditsTap: () -> Void
    let onUpgradeTap: () -> Void
    @ViewBuilder let trailingActions: () -> Actions

    init(
        profileService: ProfileService,
        tokenManager: TokenBalanceManager,
        title: String,
        onProfileTap: @escaping () -> Void,
        onCreditsTap: @escaping () -> Void,
        onUpgradeTap: @escaping () -> Void,
        @ViewBuilder trailingActions: @escaping () -> Actions = { EmptyView() }
    ) {
        self.profileService = profileService
        self.tokenManager = tokenManager
        self.title = title
        self.onProfileTap = onProfileTap
        self.onCreditsTap = onCreditsTap
        self.onUpgradeTap = onUpgradeTap
        self.trailingActions = trailingActions
    }

    var body: some View {
        VStack(spacing: 0) {
            iPadTopToolbar(
                profileService: profileService,
                tokenManager: tokenManager,
                onProfileTap: onProfileTap,
                onCreditsTap: onCreditsTap,
                onUpgradeTap: onUpgradeTap
            )

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .center, spacing: AppSpacing.sm) {
                    Text(title)
                        .font(AppTypography.displayLarge)
                        .fontWeight(.heavy)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    trailingActions()
                }
            }
            .pageMargins()
            .padding(.top, AppSpacing.sectionSpacing)
            .padding(.bottom, 0)
            .background(AppColors.backgroundLight)
        }
    }
}
