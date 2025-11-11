import SwiftUI

/// Simple toolbar content with menu + profile on left
/// Use this for views that need space for action buttons on the right
struct SimpleToolbarContent: ToolbarContent {
    @ObservedObject var profileService: ProfileService
    let onMenuTap: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            HStack(spacing: AppSpacing.xs) {
                ToolbarMenuButton(onTap: onMenuTap)
                ToolbarProfileButton(profileService: profileService)
            }
        }
    }
}
