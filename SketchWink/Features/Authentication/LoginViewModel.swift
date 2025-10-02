import Foundation
import SwiftUI
import Combine

@MainActor
class LoginViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccessAlert = false
    @Published var shouldNavigateToMainApp = false
    
    private let authService = AuthService.shared
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async {
        // Reset previous state
        errorMessage = nil
        isLoading = true
        
        // Validate input
        guard canSignIn(email: email, password: password) else {
            errorMessage = "Please enter a valid email and password (minimum 6 characters)"
            isLoading = false
            return
        }
        
        do {
            let user = try await authService.signIn(email: email, password: password)

            // Success - AppCoordinator will handle navigation automatically
            isLoading = false

            // Log success for debugging
            if AppConfig.Debug.enableLogging {
                print("✅ Login successful for user: \(user.email)")
            }
            
        } catch let error as AuthError {
            errorMessage = error.errorDescription
            isLoading = false
            
            // Log error for debugging
            if AppConfig.Debug.enableLogging {
                print("❌ Login failed: \(error.errorDescription ?? "Unknown error")")
            }
            
        } catch {
            errorMessage = "An unexpected error occurred. Please try again."
            isLoading = false
            
            // Log unexpected errors
            if AppConfig.Debug.enableLogging {
                print("❌ Unexpected login error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Validation
    func canSignIn(email: String, password: String) -> Bool {
        return AuthService.canSignIn(email: email, password: password)
    }
    
    func isValidEmail(_ email: String) -> Bool {
        return AuthService.isValidEmail(email)
    }
    
    func isValidPassword(_ password: String) -> Bool {
        return AuthService.isValidPassword(password)
    }
    
    // MARK: - Navigation
    func navigateToMainApp() {
        shouldNavigateToMainApp = true
    }
    
    // MARK: - Clear Error
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Demo Methods (for testing)
    #if DEBUG
    func signInWithDemoCredentials() async {
        await signIn(email: "test@sketchwink.com", password: "password123")
    }
    
    func simulateError() {
        errorMessage = "Demo error message for testing UI"
    }
    
    func simulateLoading() {
        isLoading = true
        
        // Stop loading after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.isLoading = false
        }
    }
    #endif
}

// MARK: - Input Validation Helpers
extension LoginViewModel {
    
    /// Returns email validation error message
    func emailValidationMessage(for email: String) -> String? {
        guard !email.isEmpty else { return nil }
        guard isValidEmail(email) else {
            return "Please enter a valid email address"
        }
        return nil
    }
    
    /// Returns password validation message
    func passwordValidationMessage(for password: String) -> String? {
        guard !password.isEmpty else { return nil }
        guard isValidPassword(password) else {
            return "Password must be at least 6 characters"
        }
        return nil
    }
    
    /// Returns overall form validation status
    func formValidationMessage(email: String, password: String) -> String? {
        if email.isEmpty || password.isEmpty {
            return "Please fill in all fields"
        }
        
        if let emailError = emailValidationMessage(for: email) {
            return emailError
        }
        
        if let passwordError = passwordValidationMessage(for: password) {
            return passwordError
        }
        
        return nil
    }
}