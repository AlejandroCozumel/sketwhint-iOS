import Foundation
import SwiftUI
import Combine

@MainActor
class SignUpViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccessAlert = false
    @Published var showOTPVerification = false
    
    private let authService = AuthService.shared
    
    // MARK: - Sign Up
    func signUp(name: String, email: String, password: String, confirmPassword: String) async {
        // Reset previous state
        errorMessage = nil
        isLoading = true
        
        // Validate input
        guard canSignUp(name: name, email: email, password: password, confirmPassword: confirmPassword) else {
            errorMessage = getValidationError(name: name, email: email, password: password, confirmPassword: confirmPassword)
            isLoading = false
            return
        }
        
        do {
            let response = try await authService.signUp(email: email, password: password, name: name)
            
            if response.success {
                // Success - show alert first, then proceed to OTP
                showSuccessAlert = true
                isLoading = false
                
                // Log success for debugging
                if AppConfig.Debug.enableLogging {
                    print("✅ Sign up successful for: \(email)")
                }
            } else {
                errorMessage = response.message
                isLoading = false
            }
            
        } catch let error as AuthError {
            errorMessage = error.errorDescription
            isLoading = false
            
            // Log error for debugging
            if AppConfig.Debug.enableLogging {
                print("❌ Sign up failed: \(error.errorDescription ?? "Unknown error")")
            }
            
        } catch {
            errorMessage = "An unexpected error occurred. Please try again."
            isLoading = false
            
            // Log unexpected errors
            if AppConfig.Debug.enableLogging {
                print("❌ Unexpected sign up error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Validation
    func canSignUp(name: String, email: String, password: String, confirmPassword: String) -> Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               AuthService.isValidEmail(email) &&
               AuthService.isValidPassword(password) &&
               password == confirmPassword
    }
    
    func getValidationError(name: String, email: String, password: String, confirmPassword: String) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            return "Please enter your full name"
        }
        
        if email.isEmpty {
            return "Please enter your email address"
        }
        
        if !AuthService.isValidEmail(email) {
            return "Please enter a valid email address"
        }
        
        if password.isEmpty {
            return "Please create a password"
        }
        
        if !AuthService.isValidPassword(password) {
            return "Password must be at least 6 characters long"
        }
        
        if confirmPassword.isEmpty {
            return "Please confirm your password"
        }
        
        if password != confirmPassword {
            return "Passwords do not match"
        }
        
        return "Please fill in all fields correctly"
    }
    
    // MARK: - Navigation
    func proceedToOTPVerification() {
        showOTPVerification = true
    }
    
    // MARK: - Clear Error
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Individual Field Validation
    func isValidName(_ name: String) -> Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func isValidEmail(_ email: String) -> Bool {
        return AuthService.isValidEmail(email)
    }
    
    func isValidPassword(_ password: String) -> Bool {
        return AuthService.isValidPassword(password)
    }
    
    func passwordsMatch(_ password: String, _ confirmPassword: String) -> Bool {
        return password == confirmPassword && !password.isEmpty
    }
    
    // MARK: - Demo Methods (for testing)
    #if DEBUG
    func signUpWithDemoData() async {
        await signUp(
            name: "Demo Family",
            email: "demo@sketchwink.com", 
            password: "password123",
            confirmPassword: "password123"
        )
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

// MARK: - Validation Helpers
extension SignUpViewModel {
    
    /// Returns name validation message
    func nameValidationMessage(for name: String) -> String? {
        guard !name.isEmpty else { return nil }
        guard isValidName(name) else {
            return "Please enter your full name"
        }
        return nil
    }
    
    /// Returns email validation message
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
    
    /// Returns confirm password validation message
    func confirmPasswordValidationMessage(for password: String, confirmPassword: String) -> String? {
        guard !confirmPassword.isEmpty else { return nil }
        guard passwordsMatch(password, confirmPassword) else {
            return "Passwords do not match"
        }
        return nil
    }
    
    /// Returns overall form validation status
    func formValidationMessage(name: String, email: String, password: String, confirmPassword: String) -> String? {
        if let nameError = nameValidationMessage(for: name) {
            return nameError
        }
        
        if let emailError = emailValidationMessage(for: email) {
            return emailError
        }
        
        if let passwordError = passwordValidationMessage(for: password) {
            return passwordError
        }
        
        if let confirmError = confirmPasswordValidationMessage(for: password, confirmPassword: confirmPassword) {
            return confirmError
        }
        
        return nil
    }
}