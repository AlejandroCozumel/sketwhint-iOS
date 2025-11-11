import SwiftUI

struct ToolbarProfileButton: View {
    @ObservedObject var profileService: ProfileService

    var body: some View {
        NavigationLink {
            ProfilesView()
        } label: {
            HStack(spacing: 6) {
                if let currentProfile = profileService.currentProfile {
                    Text(currentProfile.displayAvatar)
                        .font(.system(size: 24))

                    Text(currentProfile.name)
                        .font(AppTypography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
    }
}
