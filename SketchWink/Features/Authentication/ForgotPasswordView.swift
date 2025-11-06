import SwiftUI

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showResetCodeView = false
    @FocusState private var emailFocused: Bool

    init(prefilledEmail: String = "") {
        _email = State(initialValue: prefilledEmail)
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundLight
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        // Header
                        VStack(spacing: AppSpacing.md) {
                            Image(systemName: "lock.rotation")
                                .font(.system(size: 64))
                                .foregroundColor(AppColors.primaryBlue)

                            Text("Reset Password")
                                .font(AppTypography.headlineLarge)
                                .foregroundColor(AppColors.textPrimary)

                            Text("Enter your email address and we'll send you a code to reset your password")
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, AppSpacing.md)
                        }
                        .padding(.top, AppSpacing.xxl)

                        // Email field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email")
                                .font(AppTypography.captionLarge)
                                .foregroundColor(AppColors.textSecondary)

                            TextField("Enter your email", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($emailFocused)
                                .font(AppTypography.bodyMedium)
                                .frame(height: 48)
                                .padding(.horizontal, AppSpacing.md)
                                .background(AppColors.backgroundLight)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            emailFocused
                                                ? AppColors.primaryBlue
                                                : AppColors.borderLight,
                                            lineWidth: emailFocused ? 2 : 1
                                        )
                                )
                        }
                        .padding(.horizontal, AppSpacing.xl)

                        // Error message
                        if let errorMessage = errorMessage {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(AppColors.errorRed)

                                Text(errorMessage)
                                    .font(AppTypography.captionLarge)
                                    .foregroundColor(AppColors.errorRed)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(AppSpacing.md)
                            .background(AppColors.errorRed.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal, AppSpacing.xl)
                        }

                        // Send code button
                        Button(action: sendResetCode) {
                            HStack(spacing: AppSpacing.sm) {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Send Reset Code")
                                        .font(AppTypography.buttonLarge)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                        }
                        .background(
                            canSend
                                ? AppColors.primaryBlue
                                : AppColors.buttonDisabled
                        )
                        .cornerRadius(AppSizing.cornerRadius.round)
                        .disabled(!canSend || isLoading)
                        .padding(.horizontal, AppSpacing.xl)
                        .shadow(
                            color: canSend ? AppColors.primaryBlue.opacity(0.3) : Color.clear,
                            radius: 12,
                            x: 0,
                            y: 4
                        )

                        Spacer()
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
            }
            .dismissableFullScreenCover(isPresented: $showResetCodeView) {
                ResetPasswordView(email: email) {
                    // Callback when password reset is successful
                    dismiss()  // Dismiss ForgotPasswordView
                }
            }
        }
    }

    private var canSend: Bool {
        !email.isEmpty && email.contains("@")
    }

    private func sendResetCode() {
        emailFocused = false
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await AuthService.shared.requestPasswordReset(email: email)

                await MainActor.run {
                    isLoading = false
                    showResetCodeView = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    if let authError = error as? AuthError {
                        errorMessage = authError.userFriendlyMessage
                    } else {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}
