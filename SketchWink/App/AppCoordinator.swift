import SwiftUI

struct AppCoordinator: View {
    @StateObject private var authService = AuthService.shared
    @State private var isCheckingAuth = true
    
    var body: some View {
        Group {
            if isCheckingAuth {
                // Loading screen while checking authentication
                SplashView()
            } else if authService.isAuthenticated {
                // User is logged in - show main app
                MainAppView()
            } else {
                // User not logged in - show login
                NavigationView {
                    LoginView()
                }
            }
        }
        .onAppear {
            Task {
                await checkAuthenticationStatus()
            }
        }
    }
    
    private func checkAuthenticationStatus() async {
        await authService.checkAuthenticationStatus()
        
        // Add a small delay for smooth transition
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await MainActor.run {
            isCheckingAuth = false
        }
    }
}

// MARK: - Splash View
struct SplashView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background using your constants
            AppColors.primaryBlue
                .ignoresSafeArea()
            
            VStack(spacing: AppSpacing.xl) {
                // App logo with animation
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 200, height: 200)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                    
                    Circle()
                        .fill(.white.opacity(0.1))
                        .frame(width: 150, height: 150)
                        .scaleEffect(isAnimating ? 1.2 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                    
                    Text("🎨")
                        .font(.system(size: 80))
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                }
                
                VStack(spacing: AppSpacing.md) {
                    Text("SketchWink")
                        .font(AppTypography.appTitle)
                        .foregroundColor(.white)
                    
                    Text("AI-Powered Creative Platform for Families")
                        .onboardingBody()
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                    
                    // Loading indicator
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                        .padding(.top, AppSpacing.lg)
                }
            }
            .contentPadding()
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - App Root View (Update your main app)
struct AppRootView: View {
    var body: some View {
        AppCoordinator()
            .preferredColorScheme(.light) // Force light mode for family-friendly appearance
    }
}

// MARK: - Preview
#if DEBUG
struct AppCoordinator_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Splash screen
            SplashView()
                .previewDisplayName("Splash Screen")
            
            // Not authenticated
            AppCoordinator()
                .onAppear {
                    AuthService.shared.isAuthenticated = false
                }
                .previewDisplayName("Login Flow")
            
            // Authenticated
            AppCoordinator()
                .onAppear {
                    AuthService.shared.isAuthenticated = true
                    AuthService.shared.currentUser = User(
                        id: "preview_user",
                        email: "demo@sketchwink.com", 
                        name: "Demo User",
                        image: nil,
                        emailVerified: true,
                        createdAt: "2024-01-01T00:00:00.000Z",
                        updatedAt: "2024-01-01T00:00:00.000Z",
                        role: "user",
                        promptEnhancementEnabled: true
                    )
                }
                .previewDisplayName("Main App")
        }
    }
}
#endif