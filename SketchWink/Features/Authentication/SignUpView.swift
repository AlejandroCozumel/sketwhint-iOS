import SwiftUI
import AuthenticationServices

struct SignUpView: View {
    @StateObject private var viewModel = SignUpViewModel()
    @StateObject private var localization = LocalizationManager.shared
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
            let isIPad = geometry.size.width > 600

            ZStack(alignment: .topLeading) {
                // Background for safe areas
                VStack(spacing: 0) {
                    AppColors.primaryPurple
                        .ignoresSafeArea(edges: .top)

                    Spacer()

                    Color.white
                        .ignoresSafeArea(edges: .bottom)
                }

                ScrollView {
                    VStack(spacing: 0) {
                        // Logo and header section
                        ZStack {
                            // Solid purple background
                            AppColors.primaryPurple

                            VStack(spacing: 0) {
                                Spacer()
                                    .frame(height: 5)

                                // App logo
                                Image("sketchwink-logo")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 180, height: 180)
                                    .clipShape(Circle())

                                // Title
                                VStack(spacing: AppSpacing.sm) {
                                    Text("signup.title".localized)
                                        .font(AppTypography.displayLarge)
                                        .foregroundColor(.white)

                                    Text("signup.subtitle".localized)
                                        .font(AppTypography.bodyMedium)
                                        .foregroundColor(.white.opacity(0.9))
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .padding(.bottom, 32)
                        }

                        // White card with form
                        VStack(spacing: AppSpacing.lg) {
                            // Form fields
                            VStack(spacing: AppSpacing.md) {
                                // Name Field
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("common.name".localized)
                                        .font(AppTypography.captionLarge)
                                        .foregroundColor(AppColors.textSecondary)

                                    TextField("signup.name.placeholder".localized, text: $name)
                                        .textInputAutocapitalization(.words)
                                        .focused($focusedField, equals: .name)
                                        .onSubmit {
                                            focusedField = .email
                                        }
                                        .font(AppTypography.bodyMedium)
                                        .frame(height: 48)
                                        .padding(.horizontal, AppSpacing.md)
                                        .background(AppColors.backgroundLight)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    focusedField == .name
                                                        ? AppColors.primaryPurple
                                                        : AppColors.borderLight,
                                                    lineWidth: focusedField == .name ? 2 : 1
                                                )
                                        )
                                }

                                // Email Field
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("common.email".localized)
                                        .font(AppTypography.captionLarge)
                                        .foregroundColor(AppColors.textSecondary)

                                    TextField("signup.email.placeholder".localized, text: $email)
                                        .keyboardType(.emailAddress)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .focused($focusedField, equals: .email)
                                        .onSubmit {
                                            focusedField = .password
                                        }
                                        .font(AppTypography.bodyMedium)
                                        .frame(height: 48)
                                        .padding(.horizontal, AppSpacing.md)
                                        .background(AppColors.backgroundLight)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    focusedField == .email
                                                        ? AppColors.primaryPurple
                                                        : AppColors.borderLight,
                                                    lineWidth: focusedField == .email ? 2 : 1
                                                )
                                        )
                                }

                                // Password Field
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("common.password".localized)
                                        .font(AppTypography.captionLarge)
                                        .foregroundColor(AppColors.textSecondary)

                                    HStack(spacing: 0) {
                                        Group {
                                            if showPassword {
                                                TextField("signup.password.placeholder".localized, text: $password)
                                            } else {
                                                SecureField("signup.password.placeholder".localized, text: $password)
                                            }
                                        }
                                        .focused($focusedField, equals: .password)
                                        .onSubmit {
                                            focusedField = .confirmPassword
                                        }
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
                                                focusedField == .password
                                                    ? AppColors.primaryPurple
                                                    : AppColors.borderLight,
                                                lineWidth: focusedField == .password ? 2 : 1
                                            )
                                    )
                                }

                                // Confirm Password Field
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("signup.confirm.password.placeholder".localized)
                                        .font(AppTypography.captionLarge)
                                        .foregroundColor(AppColors.textSecondary)

                                    HStack(spacing: 0) {
                                        Group {
                                            if showConfirmPassword {
                                                TextField("signup.confirm.password.placeholder".localized, text: $confirmPassword)
                                            } else {
                                                SecureField("signup.confirm.password.placeholder".localized, text: $confirmPassword)
                                            }
                                        }
                                        .focused($focusedField, equals: .confirmPassword)
                                        .onSubmit {
                                            Task {
                                                await viewModel.signUp(
                                                    name: name,
                                                    email: email,
                                                    password: password,
                                                    confirmPassword: confirmPassword
                                                )
                                            }
                                        }
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
                                                focusedField == .confirmPassword
                                                    ? AppColors.primaryPurple
                                                    : AppColors.borderLight,
                                                lineWidth: focusedField == .confirmPassword ? 2 : 1
                                            )
                                    )
                                }
                            }

                            // Error Message
                            if let errorMessage = viewModel.errorMessage {
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
                            }

                            // Sign Up Button
                            Button(action: {
                                Task {
                                    await viewModel.signUp(
                                        name: name,
                                        email: email,
                                        password: password,
                                        confirmPassword: confirmPassword
                                    )
                                }
                            }) {
                                HStack(spacing: AppSpacing.sm) {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("signup.create.button".localized)
                                            .font(AppTypography.buttonText)
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                            }
                            .background(
                                viewModel.canSignUp(
                                    name: name,
                                    email: email,
                                    password: password,
                                    confirmPassword: confirmPassword
                                ) ? AppColors.primaryPurple : AppColors.buttonDisabled
                            )
                            .cornerRadius(AppSizing.cornerRadius.round)
                            .disabled(!viewModel.canSignUp(
                                name: name,
                                email: email,
                                password: password,
                                confirmPassword: confirmPassword
                            ) || viewModel.isLoading)
                            .shadow(
                                color: viewModel.canSignUp(
                                    name: name,
                                    email: email,
                                    password: password,
                                    confirmPassword: confirmPassword
                                ) ? AppColors.primaryPurple.opacity(0.3) : Color.clear,
                                radius: 12,
                                x: 0,
                                y: 4
                            )

                            // Divider
                            HStack(spacing: AppSpacing.md) {
                                Rectangle()
                                    .fill(AppColors.borderLight)
                                    .frame(height: 1)

                                Text("signup.or.divider".localized)
                                    .font(AppTypography.captionLarge)
                                    .foregroundColor(AppColors.textSecondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                    .layoutPriority(1)

                                Rectangle()
                                    .fill(AppColors.borderLight)
                                    .frame(height: 1)
                            }

                            // Social login buttons
                            VStack(spacing: AppSpacing.md) {
                                // Apple sign in button
                                AppleSignInButton(viewModel: viewModel, buttonLabel: .signUp)

                                // Google sign in button
                                GoogleSignInButton(action: {
                                    viewModel.signInWithGoogle()
                                })
                            }

                            // Sign in link
                            Button(action: {
                                dismiss()
                            }) {
                                Text("signup.login.prompt".localized)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.primaryPurple)
                            }
                            .padding(.top, AppSpacing.xs)
                        }
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.top, AppSpacing.xl)
                        .background(Color.white)
                        .cornerRadius(32, corners: [.topLeft, .topRight])
                    }
                    .padding(.horizontal, isIPad ? 200 : 0)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)

                // Back button overlay (absolute position - top-left)
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(.leading, AppSpacing.md)
                .padding(0)

                // Language switcher overlay (absolute position - top-right)
                VStack {
                    HStack {
                        Spacer()
                        LanguageSwitcherButton()
                            .padding(.trailing, AppSpacing.md)
                            .padding(.top, 0)
                    }
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $viewModel.showOTPVerification) {
            OTPVerificationView(email: email)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SignUpView()
        }
    }
}
#endif
