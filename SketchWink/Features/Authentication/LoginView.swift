import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var showSignUp = false
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: AppSpacing.lg) {

                    // Spacer for better vertical centering
                    Spacer()
                        .frame(minHeight: AppSpacing.lg)

                    // Header Section - More playful and child-friendly
                    VStack(spacing: AppSpacing.lg) {
                        // Magical logo with gradient and animation
                        ZStack {
                            // Outer glow ring
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.primaryBlue.opacity(0.3), AppColors.primaryPurple.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 140, height: 140)

                            // Main logo circle
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.primaryBlue, AppColors.primaryPurple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text("🎨")
                                        .font(.system(size: 50))
                                )
                                .shadow(
                                    color: AppColors.primaryBlue.opacity(0.4),
                                    radius: 20,
                                    x: 0,
                                    y: 8
                                )
                        }

                        // Welcome text with improved hierarchy
                        VStack(spacing: AppSpacing.sm) {
                            Text("Welcome to")
                                .titleLarge()
                                .foregroundColor(.white)

                            Text("SketchWink")
                                .font(AppTypography.appTitle)
                                .foregroundColor(.white)

                            Text("Where families create magic together! ✨")
                                .onboardingBody()
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, AppSpacing.md)
                        }
                    }

                    // Login Form - Full width design
                    VStack(spacing: AppSpacing.md) {
                        VStack(spacing: AppSpacing.md) {
                            // Email Field - Consistent style
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

                            // Password Field - Consistent style
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Password")
                                    .captionLarge()
                                    .foregroundColor(.white)

                                HStack {
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

                                    Button(action: { showPassword.toggle() }) {
                                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(.white)
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
                        }

                        // Error Message - More friendly design
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

                        // Login Button - More prominent and friendly
                        Button(action: {
                            Task {
                                await viewModel.signIn(email: email, password: password)
                            }
                        }) {
                            HStack(spacing: AppSpacing.sm) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .tint(AppColors.textOnColor)
                                        .scaleEffect(0.9)
                                } else {
                                    Image(systemName: "sparkles")
                                        .font(.title2)
                                        .foregroundColor(viewModel.canSignIn(email: email, password: password) ? AppColors.textPrimary : AppColors.textSecondary)
                                }

                                Text(viewModel.isLoading ? "Creating Magic..." : "Start Creating!")
                                    .font(.body)
                                    .foregroundColor(viewModel.canSignIn(email: email, password: password) ? AppColors.textPrimary : AppColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .padding(.horizontal, AppSpacing.sm)
                        }
                        .background(
                            viewModel.canSignIn(email: email, password: password)
                                ? AppColors.goldenYellow
                                : AppColors.buttonDisabled
                        )
                        .cornerRadius(AppSizing.cornerRadius.sm)
                        .disabled(!viewModel.canSignIn(email: email, password: password) || viewModel.isLoading)
                        .childSafeTouchTarget()
                        .shadow(
                            color: viewModel.canSignIn(email: email, password: password)
                                ? AppColors.goldenYellow.opacity(0.3)
                                : Color.clear,
                            radius: 10,
                            x: 0,
                            y: 6
                        )

                        // OR Divider
                        HStack {
                            Rectangle()
                                .fill(.white.opacity(0.3))
                                .frame(height: 1)
                            
                            Text("OR")
                                .captionLarge()
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, AppSpacing.md)
                            
                            Rectangle()
                                .fill(.white.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.vertical, AppSpacing.md)

                        // Google Login Button
                        Button(action: {
                            // TODO: Implement Google login
                            print("Google login tapped")
                        }) {
                            HStack(spacing: AppSpacing.sm) {
                                // Google icon (using system image for now)
                                Image(systemName: "globe")
                                    .font(.title2)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text("Continue with Google")
                                    .font(.body)
                                    .foregroundColor(AppColors.textPrimary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .padding(.horizontal, AppSpacing.sm)
                        }
                        .background(.white)
                        .cornerRadius(AppSizing.cornerRadius.sm)
                        .childSafeTouchTarget()
                        .shadow(
                            color: .black.opacity(0.1),
                            radius: 8,
                            x: 0,
                            y: 4
                        )

                        // Sign Up Link
                        HStack(spacing: AppSpacing.xs) {
                            Text("New to SketchWink?")
                                .bodyMedium()
                                .foregroundColor(.white)
                            
                            Button("Sign up") {
                                showSignUp = true
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
        .background(AppColors.dreamyBlue)
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showSignUp) {
            SignUpView()
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