import SwiftUI

struct OTPVerificationView: View {
    let email: String
    let onVerificationComplete: (() -> Void)?
    @StateObject private var viewModel = OTPVerificationViewModel()
    @StateObject private var localization = LocalizationManager.shared
    @State private var otpCode = ""
    @FocusState private var isOTPFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(email: String, onVerificationComplete: (() -> Void)? = nil) {
        self.email = email
        self.onVerificationComplete = onVerificationComplete
    }

    var body: some View {
        GeometryReader { geometry in
            let isIPad = geometry.size.width > 600
            let horizontalInset = isIPad
                ? min(max(geometry.size.width * 0.12, 70), 180)
                : 0
            let bottomPadding = isIPad ? AppSpacing.xl : AppSpacing.lg
            let cardCorners: UIRectCorner = isIPad ? [.allCorners] : [.topLeft, .topRight]

            ZStack(alignment: .topTrailing) {
                // Background for safe areas
                VStack(spacing: 0) {
                    AppColors.primaryBlue
                        .ignoresSafeArea(edges: .top)

                    Spacer()

                    Color.white
                        .ignoresSafeArea(edges: .bottom)
                }

                ScrollView {
                    VStack(spacing: 0) {
                        // Header section
                        ZStack {
                            // Solid blue background
                            AppColors.primaryBlue

                            VStack(spacing: 0) {
                                // Back button
                                HStack {
                                    Button(action: { dismiss() }) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "arrow.left")
                                                .font(.system(size: 20, weight: .semibold))
                                            Text("common.back".localized)
                                                .font(AppTypography.bodyMedium)
                                        }
                                        .foregroundColor(.white)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, AppSpacing.xl)
                                .padding(.top, AppSpacing.md)
                                
                                Spacer()
                                    .frame(height: 20)

                                // Icon/Logo area
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 100, height: 100)
                                    
                                    Image(systemName: "envelope.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white)
                                }
                                .padding(.bottom, AppSpacing.md)

                                // Title
                                VStack(spacing: AppSpacing.sm) {
                                    Text("otp.title".localized)
                                        .font(AppTypography.displayLarge)
                                        .foregroundColor(.white)

                                    Text("otp.subtitle".localized)
                                        .font(AppTypography.bodyMedium)
                                        .foregroundColor(.white.opacity(0.9))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, AppSpacing.lg)
                                    
                                    Text(email)
                                        .font(AppTypography.bodyMedium)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, AppSpacing.md)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.2))
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.bottom, 40)
                        }

                        // White card with content
                        VStack(spacing: 0) {
                            Spacer()

                            VStack(spacing: AppSpacing.lg) {
                                // OTP Input Section
                                VStack(spacing: AppSpacing.xl) {
                                    Text("otp.code.placeholder".localized)
                                        .font(AppTypography.headlineMedium)
                                        .foregroundColor(AppColors.textPrimary)

                                    // OTP Input Field
                                    HStack(spacing: AppSpacing.sm) {
                                        ForEach(0..<6, id: \.self) { index in
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(AppColors.backgroundLight)
                                                    .frame(width: 50, height: 60)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 16)
                                                            .stroke(
                                                                isOTPFocused && index == otpCode.count ? AppColors.primaryBlue : AppColors.borderLight,
                                                                lineWidth: isOTPFocused && index == otpCode.count ? 2 : 1
                                                            )
                                                    )

                                                if index < otpCode.count {
                                                    Text(String(otpCode[otpCode.index(otpCode.startIndex, offsetBy: index)]))
                                                        .font(.title)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(AppColors.primaryBlue)
                                                }
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
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

                                    Text("otp.tap.to.enter".localized)
                                        .font(AppTypography.captionLarge)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .frame(maxWidth: .infinity)

                                // Error Message
                                if let errorMessage = viewModel.errorMessage {
                                    HStack(spacing: AppSpacing.sm) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(AppColors.errorRed)
                                            .font(.title3)

                                        Text(errorMessage)
                                            .font(AppTypography.bodyMedium)
                                            .foregroundColor(AppColors.errorRed)
                                            .multilineTextAlignment(.leading)

                                        Spacer()
                                    }
                                    .padding(AppSpacing.md)
                                    .background(AppColors.errorRed.opacity(0.1))
                                    .cornerRadius(12)
                                }

                                // Auto-verification status
                                if viewModel.isLoading {
                                    HStack(spacing: AppSpacing.sm) {
                                        ProgressView()
                                            .tint(AppColors.primaryBlue)
                                            .scaleEffect(0.8)

                                        Text("otp.verifying.loading".localized)
                                            .font(AppTypography.bodyMedium)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                }

                                // Resend Code Section
                                VStack(spacing: AppSpacing.sm) {
                                    Text("otp.resend.prompt".localized)
                                        .font(AppTypography.bodyMedium)
                                        .foregroundColor(AppColors.textSecondary)

                                    if viewModel.canResendOTP {
                                        Button(action: {
                                            Task {
                                                await viewModel.resendOTP(email: email)
                                            }
                                        }) {
                                            Text("otp.resend.button".localized)
                                                .font(AppTypography.buttonText)
                                                .foregroundColor(AppColors.primaryBlue)
                                                .padding(.horizontal, AppSpacing.lg)
                                                .padding(.vertical, AppSpacing.sm)
                                                .background(AppColors.primaryBlue.opacity(0.1))
                                                .cornerRadius(AppSizing.cornerRadius.round)
                                        }
                                    } else {
                                        Text("otp.resend.countdown".localized(with: viewModel.resendCountdown))
                                            .font(AppTypography.captionLarge)
                                            .foregroundColor(AppColors.textSecondary)
                                            .monospacedDigit()
                                    }
                                }
                                .padding(.top, AppSpacing.sm)

                                // Success Message (Resend)
                                if viewModel.showSuccessMessage {
                                    HStack(spacing: AppSpacing.sm) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(AppColors.successGreen)
                                            .font(.title3)

                                        Text("otp.resent.message".localized)
                                            .font(AppTypography.bodyMedium)
                                            .foregroundColor(AppColors.successGreen)

                                        Spacer()
                                    }
                                    .padding(AppSpacing.md)
                                    .background(AppColors.successGreen.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }

                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.top, AppSpacing.xl)
                        .padding(.bottom, bottomPadding)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(32, corners: cardCorners)
                        .overlay(
                            RoundedCorner(radius: 32, corners: cardCorners)
                                .stroke(
                                    AppColors.borderLight.opacity(isIPad ? 0.6 : 0),
                                    lineWidth: isIPad ? 1 : 0
                                )
                        )
                        .shadow(
                            color: Color.black.opacity(isIPad ? 0.08 : 0),
                            radius: isIPad ? 24 : 0,
                            x: 0,
                            y: isIPad ? 12 : 0
                        )
                    }
                    .frame(minHeight: geometry.size.height)
                    .padding(.horizontal, horizontalInset)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.startResendTimer()
            viewModel.onVerificationComplete = onVerificationComplete
            isOTPFocused = true
        }
        .overlay(
            // Success Toast
            Group {
                if viewModel.showSuccessToast {
                    VStack(spacing: AppSpacing.sm) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.successGreen)
                                .font(.title2)

                            Text("otp.success.message".localized)
                                .font(AppTypography.titleMedium)
                                .foregroundColor(AppColors.successGreen)

                            Spacer()
                        }
                        .padding(AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                        )
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, 60) // Adjust for safe area
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.showSuccessToast)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        )
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