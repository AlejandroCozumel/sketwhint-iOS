import Foundation
import SwiftUI
import Combine
import AuthenticationServices
import CryptoKit
import Security

@MainActor
class LoginViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccessAlert = false
    @Published var shouldNavigateToMainApp = false
    @Published var isPerformingAppleSignIn = false
    
    private let authService = AuthService.shared
    private var currentAppleNonce: (raw: String, hashed: String)?
    
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
    
    // MARK: - Sign In with Apple
    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]

        let rawNonce = randomNonceString()
        let hashedNonce = sha256(rawNonce)
        currentAppleNonce = (rawNonce, hashedNonce)
        request.nonce = hashedNonce
    }

    func cancelAppleSignInFlow() {
        resetAppleSignInState()
    }

    func signInWithApple(using credential: ASAuthorizationAppleIDCredential) async {
        errorMessage = nil
        isLoading = true
        isPerformingAppleSignIn = true

        guard let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            errorMessage = "We couldn't verify your Apple account. Please try again."
            resetAppleSignInState()
            return
        }

        let hashedNonce = currentAppleNonce?.hashed

        do {
            let user = try await authService.signInWithApple(
                identityToken: identityToken,
                hashedNonce: hashedNonce,
                givenName: credential.fullName?.givenName,
                familyName: credential.fullName?.familyName,
                email: credential.email,
                requestSignUp: true
            )

            isLoading = false
            isPerformingAppleSignIn = false
            currentAppleNonce = nil

            if AppConfig.Debug.enableLogging {
                print("✅ Apple sign-in successful for user: \(user.email)")
            }

        } catch let error as AuthError {
            errorMessage = error.errorDescription
            resetAppleSignInState()

            if AppConfig.Debug.enableLogging {
                print("❌ Apple sign-in failed: \(error.errorDescription ?? "Unknown error")")
            }

        } catch {
            errorMessage = "An unexpected error occurred. Please try again."
            resetAppleSignInState()

            if AppConfig.Debug.enableLogging {
                print("❌ Unexpected Apple sign-in error: \(error.localizedDescription)")
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

// MARK: - Private Helpers
private extension LoginViewModel {
    func resetAppleSignInState() {
        isLoading = false
        isPerformingAppleSignIn = false
        currentAppleNonce = nil
    }

    func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randomBytes = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)

            if status != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with status \(status)")
            }

            randomBytes.forEach { byte in
                if remainingLength == 0 {
                    return
                }

                let index = Int(byte)
                if index < charset.count {
                    result.append(charset[index])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}
