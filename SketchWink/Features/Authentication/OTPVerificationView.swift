import SwiftUI

struct OTPVerificationView: View {
    let email: String
    @StateObject private var viewModel = OTPVerificationViewModel()
    @State private var otpCode = ""
    @FocusState private var isOTPFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: AppSpacing.xl) {

                    // Header Section
                    VStack(spacing: AppSpacing.lg) {
                        // Back button
                        HStack {
                            Button(action: { dismiss() }) {
                                HStack {
                                    Image(systemName: "arrow.left")
                                    Text("Back")
                                }
                                .foregroundColor(AppColors.primaryBlue)
                            }
                            Spacer()
                        }

                        // Verification icon
                        ZStack {
                            // Outer glow ring
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.successGreen.opacity(0.3), AppColors.aqua.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 140, height: 140)

                            // Main logo circle
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.successGreen, AppColors.aqua],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text("📧")
                                        .font(.system(size: 50))
                                )
                                .shadow(
                                    color: AppColors.successGreen.opacity(0.4),
                                    radius: 20,
                                    x: 0,
                                    y: 8
                                )
                        }

                        // Verification text
                        VStack(spacing: AppSpacing.sm) {
                            Text("Check Your Email!")
                                .font(AppTypography.appTitle)
                                .foregroundColor(AppColors.successGreen)

                            Text("We've sent a 6-digit verification code to:")
                                .onboardingBody()
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)

                            Text(email)
                                .titleMedium()
                                .foregroundColor(AppColors.primaryBlue)
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.xs)
                                .background(AppColors.primaryBlue.opacity(0.1))
                                .cornerRadius(AppSizing.cornerRadius.sm)
                        }
                    }

                    // OTP Input Section
                    VStack(spacing: AppSpacing.lg) {
                        VStack(spacing: AppSpacing.md) {
                            Text("Enter Verification Code")
                                .headlineMedium()
                                .foregroundColor(AppColors.textPrimary)

                            // OTP Input Field
                            HStack(spacing: AppSpacing.sm) {
                                ForEach(0..<6, id: \.self) { index in
                                    ZStack {
                                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                                            .fill(AppColors.surfaceLight)
                                            .frame(width: 45, height: 55)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                                                    .stroke(
                                                        isOTPFocused && index == otpCode.count ? AppColors.successGreen : AppColors.borderLight,
                                                        lineWidth: isOTPFocused && index == otpCode.count ? 2 : 1
                                                    )
                                            )

                                        if index < otpCode.count {
                                            Text(String(otpCode[otpCode.index(otpCode.startIndex, offsetBy: index)]))
                                                .font(.title2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(AppColors.textPrimary)
                                        }
                                    }
                                }
                            }
                            .overlay(
                                // Hidden text field for input
                                TextField("", text: $otpCode)
                                    .keyboardType(.numberPad)
                                    .textContentType(.oneTimeCode)
                                    .focused($isOTPFocused)
                                    .opacity(0)
                                    .onChange(of: otpCode) { _, newValue in
                                        // Limit to 6 digits
                                        if newValue.count > 6 {
                                            otpCode = String(newValue.prefix(6))
                                        }

                                        // Auto-verify when 6 digits are entered
                                        if otpCode.count == 6 {
                                            Task {
                                                await viewModel.verifyOTP(email: email, code: otpCode)
                                            }
                                        }
                                    }
                            )
                            .onTapGesture {
                                isOTPFocused = true
                            }

                            Text("Tap above to enter the 6-digit code")
                                .captionLarge()
                                .foregroundColor(AppColors.textSecondary)
                        }

                        // Error Message
                        if let errorMessage = viewModel.errorMessage {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppColors.errorRed)
                                    .font(.title3)

                                Text(errorMessage)
                                    .bodyMedium()
                                    .foregroundColor(AppColors.errorRed)
                                    .multilineTextAlignment(.leading)

                                Spacer()
                            }
                            .padding(AppSpacing.md)
                            .background(AppColors.errorRed.opacity(0.1))
                            .cornerRadius(AppSizing.cornerRadius.lg)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                                    .stroke(AppColors.errorRed.opacity(0.3), lineWidth: 1)
                            )
                        }

                        // Verify Button
                        Button(action: {
                            Task {
                                await viewModel.verifyOTP(email: email, code: otpCode)
                            }
                        }) {
                            HStack(spacing: AppSpacing.sm) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .tint(AppColors.textOnColor)
                                        .scaleEffect(0.9)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(AppColors.textOnColor)
                                }

                                Text(viewModel.isLoading ? "Verifying..." : "Verify Code")
                                    .buttonLarge()
                                    .foregroundColor(AppColors.textOnColor)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                        }
                        .background(
                            LinearGradient(
                                colors: (otpCode.count == 6 && !viewModel.isLoading)
                                    ? [AppColors.successGreen, AppColors.aqua]
                                    : [AppColors.buttonDisabled, AppColors.buttonDisabled],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(AppSizing.cornerRadius.lg)
                        .disabled(otpCode.count != 6 || viewModel.isLoading)
                        .childSafeTouchTarget()
                        .shadow(
                            color: (otpCode.count == 6 && !viewModel.isLoading)
                                ? AppColors.successGreen.opacity(0.3)
                                : Color.clear,
                            radius: 10,
                            x: 0,
                            y: 6
                        )

                        // Resend Code Section
                        VStack(spacing: AppSpacing.sm) {
                            Text("Didn't receive the code?")
                                .bodyMedium()
                                .foregroundColor(AppColors.textSecondary)

                            if viewModel.canResendOTP {
                                Button("Resend Code") {
                                    Task {
                                        await viewModel.resendOTP(email: email)
                                    }
                                }
                                .padding(.horizontal, AppSpacing.lg)
                                .padding(.vertical, AppSpacing.sm)
                                .background(AppColors.buttonSecondary)
                                .foregroundColor(AppColors.primaryBlue)
                                .cornerRadius(AppSizing.cornerRadius.lg)
                                .childSafeTouchTarget()
                            } else {
                                Text("Resend available in \(viewModel.resendCountdown)s")
                                    .captionLarge()
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }

                        // Success Message
                        if viewModel.showSuccessMessage {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.successGreen)
                                    .font(.title3)

                                Text("Code sent successfully!")
                                    .bodyMedium()
                                    .foregroundColor(AppColors.successGreen)

                                Spacer()
                            }
                            .padding(AppSpacing.md)
                            .background(AppColors.successGreen.opacity(0.1))
                            .cornerRadius(AppSizing.cornerRadius.lg)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                                    .stroke(AppColors.successGreen.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }

                    Spacer()
                        .frame(minHeight: AppSpacing.xl)
                }
                .pageMargins()
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(
            LinearGradient(
                colors: [
                    AppColors.softMint.opacity(0.3),
                    AppColors.babyBlue.opacity(0.3),
                    AppColors.aqua.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .navigationBarHidden(true)
        .onAppear {
            viewModel.startResendTimer()
        }
        .alert("Welcome to SketchWink! 🎉", isPresented: $viewModel.showSuccessAlert) {
            Button("Start Creating! ✨") {
                viewModel.navigateToMainApp()
            }
            .foregroundColor(AppColors.primaryBlue)
        } message: {
            Text("Your account has been verified! Welcome to our creative family!")
        }
    }
}

// MARK: - Preview
#if DEBUG
struct OTPVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        OTPVerificationView(email: "test@sketchwink.com")
            .previewDisplayName("OTP Verification")

        OTPVerificationView(email: "verylongemail@sketchwink.com")
            .preferredColorScheme(.dark)
            .previewDisplayName("OTP Verification (Dark)")
    }
}
#endif