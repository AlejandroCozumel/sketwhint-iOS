import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    
                    // Header Section
                    VStack(spacing: AppSpacing.lg) {
                        // Logo placeholder
                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.xl)
                            .fill(AppColors.primaryBlue)
                            .frame(width: 120, height: 120)
                            .overlay(
                                Text("🎨")
                                    .font(.system(size: 60))
                            )
                            .shadow(
                                color: AppColors.primaryBlue.opacity(0.3),
                                radius: AppSizing.shadows.large.radius,
                                x: AppSizing.shadows.large.x,
                                y: AppSizing.shadows.large.y
                            )
                        
                        VStack(spacing: AppSpacing.sm) {
                            Text("Welcome to SketchWink")
                                .appTitle()
                            
                            Text("Create amazing art with your family")
                                .onboardingBody()
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, AppSpacing.xl)
                    
                    // Login Form
                    VStack(spacing: AppSpacing.lg) {
                        VStack(spacing: AppSpacing.md) {
                            // Email Field
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Email")
                                    .titleMedium()
                                    .foregroundColor(AppColors.textPrimary)
                                
                                HStack {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(AppColors.primaryBlue)
                                        .frame(width: AppSizing.iconSizes.md)
                                    
                                    TextField("Enter your email", text: $email)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .focused($focusedField, equals: .email)
                                        .onSubmit {
                                            focusedField = .password
                                        }
                                }
                                .formFieldStyle()
                            }
                            
                            // Password Field
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Password")
                                    .titleMedium()
                                    .foregroundColor(AppColors.textPrimary)
                                
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(AppColors.primaryBlue)
                                        .frame(width: AppSizing.iconSizes.md)
                                    
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
                                            .foregroundColor(AppColors.textSecondary)
                                            .frame(width: AppSizing.iconSizes.md)
                                    }
                                    .childSafeTouchTarget()
                                }
                                .formFieldStyle()
                            }
                        }
                        
                        // Error Message
                        if let errorMessage = viewModel.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppColors.errorRed)
                                
                                Text(errorMessage)
                                    .bodyMedium()
                                    .foregroundColor(AppColors.errorRed)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                            }
                            .contentPadding()
                            .background(AppColors.errorRed.opacity(0.1))
                            .cornerRadius(AppSizing.cornerRadius.md)
                        }
                        
                        // Login Button
                        Button(action: {
                            Task {
                                await viewModel.signIn(email: email, password: password)
                            }
                        }) {
                            HStack {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.title2)
                                }
                                
                                Text(viewModel.isLoading ? "Signing In..." : "Sign In")
                                    .buttonLarge()
                            }
                        }
                        .largeButtonStyle(
                            backgroundColor: viewModel.canSignIn(email: email, password: password) 
                                ? AppColors.primaryBlue 
                                : AppColors.buttonDisabled
                        )
                        .disabled(!viewModel.canSignIn(email: email, password: password) || viewModel.isLoading)
                        .childSafeTouchTarget()
                        
                        // Sign Up Link
                        VStack(spacing: AppSpacing.sm) {
                            Text("Don't have an account?")
                                .bodyMedium()
                                .foregroundColor(AppColors.textSecondary)
                            
                            Button("Create Account") {
                                // TODO: Navigate to sign up
                            }
                            .buttonStyle(
                                backgroundColor: AppColors.buttonSecondary,
                                foregroundColor: AppColors.primaryBlue
                            )
                        }
                    }
                    .cardStyle()
                    
                    // Demo Credentials (for testing)
                    #if DEBUG
                    VStack(spacing: AppSpacing.sm) {
                        Text("Demo Credentials")
                            .titleMedium()
                            .foregroundColor(AppColors.textSecondary)
                        
                        Button("Fill Demo Credentials") {
                            email = "richard190982@gmail.com"
                            password = "password123"
                        }
                        .buttonStyle(
                            backgroundColor: AppColors.softMint,
                            foregroundColor: AppColors.textPrimary
                        )
                    }
                    .cardStyle()
                    #endif
                    
                    Spacer(minLength: AppSpacing.xl)
                }
                .pageMargins()
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(AppColors.backgroundLight)
        .navigationBarHidden(true)
        .onTapGesture {
            focusedField = nil
        }
        .alert("Login Successful! 🎉", isPresented: $viewModel.showSuccessAlert) {
            Button("Continue") {
                viewModel.navigateToMainApp()
            }
        } message: {
            Text("Welcome to SketchWink! Let's start creating amazing art together.")
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