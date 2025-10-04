import SwiftUI

struct ResetPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.presentationMode) var presentationMode
    let email: String
    let onSuccess: () -> Void  // Callback to dismiss parent view

    @State private var code = ["", "", "", "", "", ""]
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessAlert = false
    @FocusState private var focusedIndex: Int?
    @FocusState private var passwordFocused: Bool
    @FocusState private var confirmPasswordFocused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundLight
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        // Header
                        VStack(spacing: AppSpacing.md) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 64))
                                .foregroundColor(AppColors.successGreen)

                            Text("Enter Reset Code")
                                .font(AppTypography.headlineLarge)
                                .foregroundColor(AppColors.textPrimary)

                            Text("We sent a 6-digit code to")
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textSecondary)

                            Text(email)
                                .font(AppTypography.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.primaryBlue)
                        }
                        .padding(.top, AppSpacing.xxl)

                        // OTP Code Input
                        HStack(spacing: 12) {
                            ForEach(0..<6, id: \.self) { index in
                                OTPDigitField(
                                    text: $code[index],
                                    isFocused: focusedIndex == index,
                                    onTextChange: { newValue in
                                        handleCodeInput(at: index, newValue: newValue)
                                    }
                                )
                                .focused($focusedIndex, equals: index)
                            }
                        }
                        .padding(.horizontal, AppSpacing.xl)

                        // New Password field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("New Password")
                                .font(AppTypography.captionLarge)
                                .foregroundColor(AppColors.textSecondary)

                            HStack(spacing: 0) {
                                Group {
                                    if showPassword {
                                        TextField("Enter new password", text: $newPassword)
                                    } else {
                                        SecureField("Enter new password", text: $newPassword)
                                    }
                                }
                                .focused($passwordFocused)
                                .font(AppTypography.bodyMedium)

                                Button(action: { showPassword.toggle() }) {
                                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(AppColors.textSecondary)
                                        .font(.system(size: 16))
                                        .padding(.horizontal, AppSpacing.md)
                                }
                            }
                            .frame(height: 48)
                            .padding(.leading, AppSpacing.md)
                            .background(AppColors.backgroundLight)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        passwordFocused ? AppColors.primaryBlue : AppColors.borderLight,
                                        lineWidth: passwordFocused ? 2 : 1
                                    )
                            )

                            Text("Minimum 8 characters")
                                .font(AppTypography.captionMedium)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.horizontal, AppSpacing.xl)

                        // Confirm Password field
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Confirm Password")
                                .font(AppTypography.captionLarge)
                                .foregroundColor(AppColors.textSecondary)

                            HStack(spacing: 0) {
                                Group {
                                    if showConfirmPassword {
                                        TextField("Confirm new password", text: $confirmPassword)
                                    } else {
                                        SecureField("Confirm new password", text: $confirmPassword)
                                    }
                                }
                                .focused($confirmPasswordFocused)
                                .font(AppTypography.bodyMedium)

                                Button(action: { showConfirmPassword.toggle() }) {
                                    Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(AppColors.textSecondary)
                                        .font(.system(size: 16))
                                        .padding(.horizontal, AppSpacing.md)
                                }
                            }
                            .frame(height: 48)
                            .padding(.leading, AppSpacing.md)
                            .background(AppColors.backgroundLight)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        confirmPasswordFocused ? AppColors.primaryBlue : AppColors.borderLight,
                                        lineWidth: confirmPasswordFocused ? 2 : 1
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

                        // Reset password button
                        Button(action: resetPassword) {
                            HStack(spacing: AppSpacing.sm) {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Reset Password")
                                        .font(AppTypography.buttonLarge)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                        }
                        .background(
                            canReset ? AppColors.primaryBlue : AppColors.buttonDisabled
                        )
                        .cornerRadius(AppSizing.cornerRadius.round)
                        .disabled(!canReset || isLoading)
                        .padding(.horizontal, AppSpacing.xl)
                        .shadow(
                            color: canReset ? AppColors.primaryBlue.opacity(0.3) : Color.clear,
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
            .alert("Password Reset Successful", isPresented: $showSuccessAlert) {
                Button("Sign In") {
                    // Dismiss this view first
                    dismiss()
                    // Then notify parent to dismiss itself
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onSuccess()
                    }
                }
            } message: {
                Text("Your password has been reset successfully. Please sign in with your new password.")
            }
            .onAppear {
                focusedIndex = 0
            }
        }
    }

    private var codeString: String {
        code.joined()
    }

    private var canReset: Bool {
        codeString.count == 6 &&
        newPassword.count >= 8 &&
        confirmPassword == newPassword
    }

    private func handleCodeInput(at index: Int, newValue: String) {
        // Only allow digits
        let filtered = newValue.filter { $0.isNumber }

        if filtered.count > 1 {
            // Pasted multiple digits
            let digits = Array(filtered.prefix(6))
            for (i, digit) in digits.enumerated() where i < 6 {
                code[i] = String(digit)
            }
            focusedIndex = min(digits.count, 5)
        } else if filtered.count == 1 {
            // Single digit entered
            code[index] = filtered
            if index < 5 {
                focusedIndex = index + 1
            } else {
                focusedIndex = nil
            }
        } else if newValue.isEmpty {
            // Backspace pressed
            code[index] = ""
            if index > 0 {
                focusedIndex = index - 1
            }
        }
    }

    private func resetPassword() {
        focusedIndex = nil
        passwordFocused = false
        confirmPasswordFocused = false
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await AuthService.shared.resetPassword(
                    email: email,
                    code: codeString,
                    newPassword: newPassword
                )

                await MainActor.run {
                    isLoading = false
                    showSuccessAlert = true
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

// MARK: - OTP Digit Field (Reusable component)
struct OTPDigitField: View {
    @Binding var text: String
    let isFocused: Bool
    let onTextChange: (String) -> Void

    var body: some View {
        TextField("", text: $text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 24, weight: .semibold))
            .frame(width: 48, height: 56)
            .background(AppColors.backgroundLight)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isFocused ? AppColors.primaryBlue : AppColors.borderLight,
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .onChange(of: text) { newValue in
                onTextChange(newValue)
            }
    }
}
