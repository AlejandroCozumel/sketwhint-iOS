import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthService.shared
    @StateObject private var localization = LocalizationManager.shared
    @State private var showingSignOutAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    
                    // Header
                    if let user = authService.currentUser {
                        Text(String(format: "settings.hello".localized, user.name))
                            .bodyMedium()
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .contentPadding()
                    }
                    
                    // Account Section
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("settings.account.section".localized)
                            .headlineMedium()
                            .foregroundColor(AppColors.textPrimary)

                        if let user = authService.currentUser {
                            VStack(spacing: AppSpacing.sm) {
                                SettingsRow(
                                    icon: "✉️",
                                    title: "common.email".localized,
                                    value: user.email,
                                    showChevron: false
                                )

                                SettingsRow(
                                    icon: user.emailVerified ? "✅" : "⚠️",
                                    title: "settings.email.verification".localized,
                                    value: user.emailVerified ? "settings.email.verified".localized : "settings.email.not.verified".localized,
                                    showChevron: false
                                )
                            }
                        }
                    }
                    .cardStyle()
                    
                    // App Settings Section
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("settings.app.settings.section".localized)
                            .headlineMedium()
                            .foregroundColor(AppColors.textPrimary)

                        VStack(spacing: AppSpacing.sm) {
                            SettingsRow(
                                icon: "🔔",
                                title: "settings.notifications".localized,
                                value: "settings.coming.soon".localized,
                                showChevron: true
                            )

                            NavigationLink(destination: LanguageSettingsView()) {
                                SettingsRow(
                                    icon: "🌐",
                                    title: "settings.language".localized,
                                    value: localization.currentLanguage.displayName,
                                    showChevron: true
                                )
                            }
                            .buttonStyle(.plain)

                            SettingsRow(
                                icon: "🎨",
                                title: "settings.theme".localized,
                                value: "settings.theme.light".localized,
                                showChevron: true
                            )
                        }
                    }
                    .cardStyle()
                    
                    // Support Section
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("settings.support.section".localized)
                            .headlineMedium()
                            .foregroundColor(AppColors.textPrimary)

                        VStack(spacing: AppSpacing.sm) {
                            SettingsRow(
                                icon: "❓",
                                title: "settings.help.faq".localized,
                                value: "",
                                showChevron: true
                            )

                            NavigationLink(destination: LegalDocumentView(documentType: .privacyPolicy)) {
                                SettingsRow(
                                    icon: "📝",
                                    title: "settings.privacy.policy".localized,
                                    value: "",
                                    showChevron: true
                                )
                            }
                            .buttonStyle(.plain)

                            NavigationLink(destination: LegalDocumentView(documentType: .termsOfService)) {
                                SettingsRow(
                                    icon: "📋",
                                    title: "settings.terms.service".localized,
                                    value: "",
                                    showChevron: true
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .cardStyle()
                    
                    // Sign Out Section
                    VStack(spacing: AppSpacing.sm) {
                        Button {
                            showingSignOutAlert = true
                        } label: {
                            Text("settings.signout".localized)
                                .largeButtonStyle(backgroundColor: AppColors.errorRed)
                        }

                        Text("settings.signout.subtitle".localized)
                            .captionLarge()
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .contentPadding()
                }
                .pageMargins()
                .padding(.vertical, AppSpacing.sectionSpacing)
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("settings.title".localized)
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
        .alert("settings.signout.confirm.title".localized, isPresented: $showingSignOutAlert) {
            Button("common.cancel".localized, role: .cancel) { }
            Button("settings.signout".localized, role: .destructive) {
                authService.signOut()
                dismiss()
            }
        } message: {
            Text("settings.signout.confirm.message".localized)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String
    let showChevron: Bool
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Text(icon)
                .font(.system(size: AppSizing.iconSizes.md))
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .bodyMedium()
                    .foregroundColor(AppColors.textPrimary)
                
                if !value.isEmpty {
                    Text(value)
                        .captionLarge()
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            Spacer()
            
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: AppSizing.iconSizes.sm, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .contentPadding()
        .background(AppColors.backgroundLight)
        .cornerRadius(AppSizing.cornerRadius.sm)
        .childSafeTouchTarget()
    }
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .onAppear {
                // Set mock user for preview
                AuthService.shared.currentUser = User(
                    id: "preview_user",
                    email: "demo@sketchwink.com",
                    name: "Demo User",
                    image: nil,
                    emailVerified: true,
                    createdAt: "2024-01-01T00:00:00.000Z",
                    updatedAt: "2024-01-01T00:00:00.000Z",
                    role: "user",
                    promptEnhancementEnabled: true
                )
                AuthService.shared.isAuthenticated = true
            }
    }
}
#endif
