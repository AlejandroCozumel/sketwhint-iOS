import SwiftUI

struct ToolbarProfileButton: View {
    @ObservedObject var profileService: ProfileService
    let onTap: () -> Void

    init(profileService: ProfileService, onTap: @escaping () -> Void) {
        self.profileService = profileService
        self.onTap = onTap
    }

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
