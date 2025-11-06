import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @StateObject private var localization = LocalizationManager.shared
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

                                    Text("login.subtitle".localized)
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
                                Text("common.email".localized)
                                    .font(AppTypography.captionLarge)
                                    .foregroundColor(AppColors.textSecondary)

                                TextField("login.email.placeholder".localized, text: $email)
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
                                Text("common.password".localized)
                                    .font(AppTypography.captionLarge)
                                    .foregroundColor(AppColors.textSecondary)

                                HStack(spacing: 0) {
                                    Group {
                                        if showPassword {
                                            TextField("login.password.placeholder".localized, text: $password)
                                        } else {
                                            SecureField("login.password.placeholder".localized, text: $password)
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
                            Button("login.forgot.password".localized) {
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
                                    Text("login.signin.button".localized)
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

                            Text("login.or.divider".localized)
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
                            AppleSignInButton(viewModel: viewModel, buttonLabel: .signIn)

                            // Google sign in button
                            GoogleSignInButton(action: {
                                viewModel.signInWithGoogle()
                            })
                        }

                        // Sign up link
                        Button(action: {
                            showSignUp = true
                        }) {
                            Text("login.signup.prompt".localized)
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.primaryBlue)
                        }
                        .padding(.top, AppSpacing.xs)
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.top, AppSpacing.xl)
                    .padding(.bottom, bottomPadding)
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
                .padding(.horizontal, horizontalInset)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .scrollDismissesKeyboard(.interactively)

                // Language switcher overlay (absolute position - top-right)
                LanguageSwitcherButton()
                    .padding(.trailing, AppSpacing.md)
                    .padding(.top, 0)
            }
        }
        .navigationBarHidden(true)
        .dismissableFullScreenCover(isPresented: $showSignUp) {
            NavigationStack {
                SignUpView()
            }
            .ignoresSafeArea()
        }
        .dismissableFullScreenCover(isPresented: $showForgotPassword) {
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
        .navigationViewStyle(.stack)
        .previewDisplayName("Login View")

        NavigationView {
            LoginView()
        }
        .preferredColorScheme(.dark)
        .navigationViewStyle(.stack)
        .previewDisplayName("Login View (Dark)")

        NavigationView {
            LoginView()
        }
        .navigationViewStyle(.stack)
        .previewDevice("iPad Pro (11-inch)")
        .previewDisplayName("Login View (iPad)")
    }
}
#endif
