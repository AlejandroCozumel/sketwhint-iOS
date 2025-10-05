import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var showSignUp = false
    @State private var showForgotPassword = false
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password
    }

    var body: some View {
        GeometryReader { geometry in
            let isIPad = geometry.size.width > 600

            ZStack {
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
                            // Logo and header section
                            ZStack {
                                // Solid blue background
                                AppColors.primaryBlue

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
                                        Text("SketchWink")
                                            .font(AppTypography.displayLarge)
                                            .foregroundColor(.white)

                                        Text("Create, color, and imagine together")
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
                            // Email field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Email")
                                    .font(AppTypography.captionLarge)
                                    .foregroundColor(AppColors.textSecondary)

                                TextField("Enter your email", text: $email)
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
                                                    ? AppColors.primaryBlue
                                                    : AppColors.borderLight,
                                                lineWidth: focusedField == .email ? 2 : 1
                                            )
                                    )
                            }

                            // Password field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Password")
                                    .font(AppTypography.captionLarge)
                                    .foregroundColor(AppColors.textSecondary)

                                HStack(spacing: 0) {
                                    Group {
                                        if showPassword {
                                            TextField("Enter your password", text: $password)
                                        } else {
                                            SecureField("Enter your password", text: $password)
                                        }
                                    }
                                    .focused($focusedField, equals: .password)
                                    .onSubmit {
                                        Task {
                                            await viewModel.signIn(email: email, password: password)
                                        }
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
                                                ? AppColors.primaryBlue
                                                : AppColors.borderLight,
                                            lineWidth: focusedField == .password ? 2 : 1
                                        )
                                )
                            }

                            // Forgot password button
                            Button("Forgot Password?") {
                                showForgotPassword = true
                            }
                            .font(AppTypography.captionLarge)
                            .foregroundColor(AppColors.primaryBlue)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }

                        // Error message
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

                        // Sign in button
                        Button(action: {
                            Task {
                                await viewModel.signIn(email: email, password: password)
                            }
                        }) {
                            HStack(spacing: AppSpacing.sm) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Sign In")
                                        .font(AppTypography.buttonText)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: AppSizing.buttonHeight, maxHeight: AppSizing.buttonHeight)
                        }
                        .background(
                            viewModel.canSignIn(email: email, password: password)
                                ? AppColors.primaryBlue
                                : AppColors.buttonDisabled
                        )
                        .cornerRadius(AppSizing.cornerRadius.round)
                        .disabled(!viewModel.canSignIn(email: email, password: password) || viewModel.isLoading)
                        .shadow(
                            color: viewModel.canSignIn(email: email, password: password)
                                ? AppColors.primaryBlue.opacity(0.3)
                                : Color.clear,
                            radius: 12,
                            x: 0,
                            y: 4
                        )

                        // Divider
                        HStack(spacing: AppSpacing.md) {
                            Rectangle()
                                .fill(AppColors.borderLight)
                                .frame(height: 1)

                            Text("or")
                                .font(AppTypography.captionLarge)
                                .foregroundColor(AppColors.textSecondary)

                            Rectangle()
                                .fill(AppColors.borderLight)
                                .frame(height: 1)
                        }

                        // Social login buttons
                        VStack(spacing: AppSpacing.md) {
                            // Apple sign in button
                            AppleSignInButton(viewModel: viewModel, buttonLabel: .signIn)

                            // Google sign in button
                            GoogleSignInButton(action: {
                                viewModel.signInWithGoogle()
                            })
                        }

                        // Sign up link
                        HStack(spacing: 4) {
                            Text("Don't have an account?")
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textSecondary)

                            Button("Sign up") {
                                showSignUp = true
                            }
                            .font(AppTypography.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primaryBlue)
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
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showSignUp) {
            SignUpView()
        }
        .fullScreenCover(isPresented: $showForgotPassword) {
            ForgotPasswordView(prefilledEmail: email)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LoginView()
        }
        .previewDisplayName("Login View")

        NavigationView {
            LoginView()
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Login View (Dark)")

        NavigationView {
            LoginView()
        }
        .previewDevice("iPad Pro (11-inch)")
        .previewDisplayName("Login View (iPad)")
    }
}
#endif
