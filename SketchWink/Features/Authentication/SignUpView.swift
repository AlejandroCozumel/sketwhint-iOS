import SwiftUI

struct SignUpView: View {
    @StateObject private var viewModel = SignUpViewModel()
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @FocusState private var focusedField: Field?
    @Environment(\.dismiss) private var dismiss

    enum Field {
        case name, email, password, confirmPassword
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: AppSpacing.lg) {

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

                        // Magical logo with gradient
                        ZStack {
                            // Outer glow ring
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.primaryPink.opacity(0.3), AppColors.primaryPurple.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 140, height: 140)

                            // Main logo circle
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.primaryPink, AppColors.primaryPurple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text("✨")
                                        .font(.system(size: 50))
                                )
                                .shadow(
                                    color: AppColors.primaryPink.opacity(0.4),
                                    radius: 20,
                                    x: 0,
                                    y: 8
                                )
                        }

                        // Welcome text
                        VStack(spacing: AppSpacing.sm) {
                            Text("Join the Magic!")
                                .font(AppTypography.appTitle)
                                .foregroundColor(.white)

                            Text("Create your family account and start your creative journey! 🎨")
                                .onboardingBody()
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, AppSpacing.md)
                        }
                    }

                    // Signup Form
                    VStack(spacing: AppSpacing.md) {
                        VStack(spacing: AppSpacing.md) {
                            // Name Field
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Full Name")
                                    .captionLarge()
                                    .foregroundColor(.white)

                                TextField("Enter your full name", text: $name)
                                    .textInputAutocapitalization(.words)
                                    .focused($focusedField, equals: .name)
                                    .onSubmit {
                                        focusedField = .email
                                    }
                                    .padding(AppSpacing.sm)
                                    .background(AppColors.surfaceLight)
                                    .cornerRadius(AppSizing.cornerRadius.sm)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                            .stroke(
                                                focusedField == .name ? AppColors.primaryBlue : AppColors.primaryBlue.opacity(0.3),
                                                lineWidth: focusedField == .name ? 2 : 1
                                            )
                                    )
                            }

                            // Email Field
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Email")
                                    .captionLarge()
                                    .foregroundColor(.white)

                                TextField("Enter your email", text: $email)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .focused($focusedField, equals: .email)
                                    .onSubmit {
                                        focusedField = .password
                                    }
                                    .padding(AppSpacing.sm)
                                    .background(AppColors.surfaceLight)
                                    .cornerRadius(AppSizing.cornerRadius.sm)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                            .stroke(
                                                focusedField == .email ? AppColors.primaryBlue : AppColors.primaryBlue.opacity(0.3),
                                                lineWidth: focusedField == .email ? 2 : 1
                                            )
                                    )
                            }

                            // Password Field
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Password")
                                    .captionLarge()
                                    .foregroundColor(.white)

                                HStack {
                                    Group {
                                        if showPassword {
                                            TextField("Create a password", text: $password)
                                        } else {
                                            SecureField("Create a password", text: $password)
                                        }
                                    }
                                    .focused($focusedField, equals: .password)
                                    .onSubmit {
                                        focusedField = .confirmPassword
                                    }

                                    Button(action: { showPassword.toggle() }) {
                                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(AppColors.textSecondary)
                                            .font(.body)
                                    }
                                }
                                .padding(AppSpacing.sm)
                                .background(AppColors.surfaceLight)
                                .cornerRadius(AppSizing.cornerRadius.sm)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                        .stroke(
                                            focusedField == .password ? AppColors.primaryBlue : AppColors.primaryBlue.opacity(0.3),
                                            lineWidth: focusedField == .password ? 2 : 1
                                        )
                                )
                            }

                            // Confirm Password Field
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Confirm Password")
                                    .captionLarge()
                                    .foregroundColor(.white)

                                HStack {
                                    Group {
                                        if showConfirmPassword {
                                            TextField("Confirm your password", text: $confirmPassword)
                                        } else {
                                            SecureField("Confirm your password", text: $confirmPassword)
                                        }
                                    }
                                    .focused($focusedField, equals: .confirmPassword)
                                    .onSubmit {
                                        Task {
                                            await viewModel.signUp(name: name, email: email, password: password, confirmPassword: confirmPassword)
                                        }
                                    }

                                    Button(action: { showConfirmPassword.toggle() }) {
                                        Image(systemName: showConfirmPassword ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(AppColors.textSecondary)
                                            .font(.body)
                                    }
                                }
                                .padding(AppSpacing.sm)
                                .background(AppColors.surfaceLight)
                                .cornerRadius(AppSizing.cornerRadius.sm)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                                        .stroke(
                                            focusedField == .confirmPassword ? AppColors.primaryBlue : AppColors.primaryBlue.opacity(0.3),
                                            lineWidth: focusedField == .confirmPassword ? 2 : 1
                                        )
                                )
                            }
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

                        // Sign Up Button
                        Button(action: {
                            Task {
                                await viewModel.signUp(name: name, email: email, password: password, confirmPassword: confirmPassword)
                            }
                        }) {
                            HStack(spacing: AppSpacing.sm) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .tint(AppColors.textOnColor)
                                        .scaleEffect(0.9)
                                } else {
                                    Image(systemName: "star.fill")
                                        .font(.title2)
                                        .foregroundColor(viewModel.canSignUp(name: name, email: email, password: password, confirmPassword: confirmPassword) ? AppColors.textPrimary : AppColors.textSecondary)
                                }

                                Text(viewModel.isLoading ? "Creating Account..." : "Create Account")
                                    .font(.body)
                                    .foregroundColor(viewModel.canSignUp(name: name, email: email, password: password, confirmPassword: confirmPassword) ? AppColors.textPrimary : AppColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .padding(.horizontal, AppSpacing.sm)
                        }
                        .background(
                            viewModel.canSignUp(name: name, email: email, password: password, confirmPassword: confirmPassword)
                                ? AppColors.rosyPink
                                : AppColors.buttonDisabled
                        )
                        .cornerRadius(AppSizing.cornerRadius.sm)
                        .disabled(!viewModel.canSignUp(name: name, email: email, password: password, confirmPassword: confirmPassword) || viewModel.isLoading)
                        .childSafeTouchTarget()
                        .shadow(
                            color: viewModel.canSignUp(name: name, email: email, password: password, confirmPassword: confirmPassword)
                                ? AppColors.rosyPink.opacity(0.3)
                                : Color.clear,
                            radius: 10,
                            x: 0,
                            y: 6
                        )

                        // Already have account link
                        HStack(spacing: AppSpacing.xs) {
                            Text("Already have an account?")
                                .bodyMedium()
                                .foregroundColor(.white)
                            
                            Button("Sign in") {
                                dismiss()
                            }
                            .font(.body)
                            .foregroundColor(.white)
                            .underline()
                        }
                    }

                    Spacer()
                        .frame(minHeight: AppSpacing.md)
                }
                .pageMargins()
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(AppColors.lavenderPurple)
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $viewModel.showOTPVerification) {
            OTPVerificationView(email: email) {
                // When OTP verification is complete, dismiss the entire signup flow
                dismiss()
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
            .previewDisplayName("Sign Up View")

        SignUpView()
            .preferredColorScheme(.dark)
            .previewDisplayName("Sign Up View (Dark)")
    }
}
#endif