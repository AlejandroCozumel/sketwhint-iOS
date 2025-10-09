import SwiftUI

// MARK: - Profile Menu Button Component (Reusable)
struct ProfileMenuButton: View {
    @StateObject private var profileService = ProfileService.shared
    @Binding var selectedTab: Int
    @State private var showingProfileMenu = false
    @State private var showPainting = false

    var body: some View {
        Button(action: { showingProfileMenu = true }) {
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
        .sheet(isPresented: $showingProfileMenu) {
            ProfileMenuSheet(selectedTab: $selectedTab, showPainting: $showPainting)
        }
        .fullScreenCover(isPresented: $showPainting) {
            NavigationView {
                PaintingView()
            }
        }
    }
}

// MARK: - Profile Menu Sheet (Twitter-style slide-out menu)
struct ProfileMenuSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileService = ProfileService.shared
    @Binding var selectedTab: Int
    @Binding var showPainting: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Menu items
                VStack(spacing: 0) {
                    MenuItemButton(
                        icon: "paintbrush.fill",
                        title: "Art",
                        isSelected: selectedTab == 0
                    ) {
                        selectedTab = 0
                        dismiss()
                    }

                    MenuItemButton(
                        icon: "photo.fill",
                        title: "Gallery",
                        isSelected: selectedTab == 1
                    ) {
                        selectedTab = 1
                        dismiss()
                    }

                    MenuItemButton(
                        icon: "book.fill",
                        title: "Books",
                        isSelected: selectedTab == 2
                    ) {
                        selectedTab = 2
                        dismiss()
                    }

                    MenuItemButton(
                        icon: "folder.fill",
                        title: "Folders",
                        isSelected: selectedTab == 3
                    ) {
                        selectedTab = 3
                        dismiss()
                    }

                    MenuItemButton(
                        icon: "person.2.fill",
                        title: "Profiles",
                        isSelected: selectedTab == 4
                    ) {
                        selectedTab = 4
                        dismiss()
                    }

                    Divider()
                        .padding(.vertical, AppSpacing.sm)

                    Button(action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showPainting = true
                        }
                    }) {
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: "paintbrush.pointed.fill")
                                .font(.system(size: 24))
                                .foregroundColor(AppColors.textSecondary)
                                .frame(width: 32)

                            Text("Painting")
                                .font(AppTypography.titleMedium)
                                .foregroundColor(AppColors.textPrimary)

                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.md)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, AppSpacing.lg)

                Spacer()
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.primaryBlue)
                }
            }
        }
    }
}

// MARK: - Menu Item Button
struct MenuItemButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? AppColors.primaryBlue : AppColors.textSecondary)
                    .frame(width: 32)

                Text(title)
                    .font(AppTypography.titleMedium)
                    .foregroundColor(isSelected ? AppColors.primaryBlue : AppColors.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.primaryBlue)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .background(isSelected ? AppColors.primaryBlue.opacity(0.1) : Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
