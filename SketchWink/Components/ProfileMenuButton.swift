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
                    Button(action: {
                        dismiss()
                    }) {
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
                    .accessibilityLabel("Close")
                }
            }
        }
    }
}
