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
                                .foregroundColor(AppColors.primaryPink)

                            Text("Create your family account and start your creative journey! 🎨")
                                .onboardingBody()
                                .foregroundColor(AppColors.energyOrange)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, AppSpacing.md)
                        }
                    }

                    // Signup Form
                    VStack(spacing: AppSpacing.lg) {
                        VStack(spacing: AppSpacing.md) {
                            // Name Field
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Full Name")
                                    .captionLarge()
                                    .foregroundColor(AppColors.textSecondary)

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
                                    .foregroundColor(AppColors.textSecondary)

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
                                    .foregroundColor(AppColors.textSecondary)

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
                                    .foregroundColor(AppColors.textSecondary)

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
                                        .foregroundColor(AppColors.textOnColor)
                                }

                                Text(viewModel.isLoading ? "Creating Account..." : "Create Account")
                                    .buttonLarge()
                                    .foregroundColor(AppColors.textOnColor)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppSpacing.md)
                        }
                        .background(
                            LinearGradient(
                                colors: viewModel.canSignUp(name: name, email: email, password: password, confirmPassword: confirmPassword)
                                    ? [AppColors.primaryPink, AppColors.primaryPurple]
                                    : [AppColors.buttonDisabled, AppColors.buttonDisabled],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(AppSizing.cornerRadius.lg)
                        .disabled(!viewModel.canSignUp(name: name, email: email, password: password, confirmPassword: confirmPassword) || viewModel.isLoading)
                        .childSafeTouchTarget()
                        .shadow(
                            color: viewModel.canSignUp(name: name, email: email, password: password, confirmPassword: confirmPassword)
                                ? AppColors.primaryPink.opacity(0.3)
                                : Color.clear,
                            radius: 10,
                            x: 0,
                            y: 6
                        )

                        // Already have account link
                        VStack(spacing: AppSpacing.sm) {
                            Text("Already have an account?")
                                .bodyMedium()
                                .foregroundColor(AppColors.textSecondary)

                            Button("Sign In") {
                                dismiss()
                            }
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, AppSpacing.sm)
                            .background(AppColors.buttonSecondary)
                            .foregroundColor(AppColors.primaryBlue)
                            .cornerRadius(AppSizing.cornerRadius.lg)
                            .childSafeTouchTarget()
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
                    AppColors.peachCream.opacity(0.3),
                    AppColors.lavenderMist.opacity(0.3),
                    AppColors.cottonCandy.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $viewModel.showOTPVerification) {
            OTPVerificationView(email: email)
        }
        .alert("Account Created! 🎉", isPresented: $viewModel.showSuccessAlert) {
            Button("Continue") {
                viewModel.proceedToOTPVerification()
            }
        } message: {
            Text("Please check your email for a verification code!")
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