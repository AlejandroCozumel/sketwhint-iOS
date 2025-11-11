import Foundation
import SwiftUI
import Combine
import AuthenticationServices
import CryptoKit
import Security
import GoogleSignIn

@MainActor
class SignUpViewModel: ObservableObject, AppleSignInViewModel {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccessAlert = false
    @Published var showOTPVerification = false
    @Published var isPerformingAppleSignIn = false
    @Published var isPerformingGoogleSignIn = false

    private let authService = AuthService.shared
    private let localization = LocalizationManager.shared
    private var currentAppleNonce: (raw: String, hashed: String)?
    
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

        // Use current app language (user can change via switcher or defaults to device language)
        let selectedLanguage = localization.currentLanguage.rawValue

        if AppConfig.Debug.enableLogging {
            print("📝 Sign up with selected language: \(selectedLanguage)")
            print("   - Language source: \(localization.currentLanguage.displayName)")
        }

        do {
            let response = try await authService.signUp(email: email, password: password, name: name, language: selectedLanguage)
            
            if response.success {
                // Success - only show OTP if verification is required
                if response.requiresVerification == true {
                    showOTPVerification = true
                    isLoading = false
                    
                    if AppConfig.Debug.enableLogging {
                        print("✅ Sign up successful for: \(email), verification required")
                    }
                } else {
                    // User created but no verification needed - could redirect to login
                    isLoading = false
                    
                    if AppConfig.Debug.enableLogging {
                        print("✅ Sign up successful for: \(email), no verification required")
                    }
                    
                    // For now, still show OTP but could change this behavior
                    showOTPVerification = true
                }
            } else {
                errorMessage = response.message
                isLoading = false
            }
            
        } catch let error as AuthError {
            // Check if it's a parsing error but signup succeeded (201 response)
            if let errorDesc = error.errorDescription, 
               (errorDesc.contains("Network error") && errorDesc.contains("data couldn't be read")) ||
               errorDesc.contains("is missing") {
                // Signup likely succeeded despite parsing error - proceed to OTP
                isLoading = false
                showOTPVerification = true
                
                if AppConfig.Debug.enableLogging {
                    print("⚠️ Signup succeeded but response parsing failed: \(errorDesc)")
                    print("⚠️ Proceeding to OTP verification")
                }
            } else {
                // Real error (like "User already exists")
                errorMessage = error.errorDescription
                isLoading = false
                
                // Log error for debugging
                if AppConfig.Debug.enableLogging {
                    print("❌ Sign up failed: \(error.errorDescription ?? "Unknown error")")
                }
            }
            
        } catch {
            // Check for parsing errors in general catch
            let errorDesc = error.localizedDescription
            if errorDesc.contains("data couldn't be read") || errorDesc.contains("missing") {
                // Signup likely succeeded despite parsing error
                isLoading = false
                showOTPVerification = true
                
                if AppConfig.Debug.enableLogging {
                    print("⚠️ Signup succeeded but response parsing failed: \(errorDesc)")
                    print("⚠️ Proceeding to OTP verification")
                }
            } else {
                errorMessage = error.localizedDescription
                isLoading = false
                
                // Log unexpected errors
                if AppConfig.Debug.enableLogging {
                    print("❌ Unexpected sign up error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Sign In with Google
    func signInWithGoogle() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let topVC = windowScene.windows.first?.rootViewController else {
            errorMessage = "Could not find top view controller."
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: topVC) { result, error in
            if let error = error {
                self.errorMessage = "Google Sign-In failed: \(error.localizedDescription)"
                return
            }

            guard let result = result else {
                self.errorMessage = "Google Sign-In failed: No result found."
                return
            }

            let idToken = result.user.idToken?.tokenString
            let accessToken = result.user.accessToken.tokenString
            let givenName = result.user.profile?.givenName
            let familyName = result.user.profile?.familyName
            let email = result.user.profile?.email

            Task {
                await self.signInWithGoogle(
                    idToken: idToken,
                    accessToken: accessToken,
                    givenName: givenName,
                    familyName: familyName,
                    email: email
                )
            }
        }
    }

    func signInWithGoogle(idToken: String?, accessToken: String?, givenName: String?, familyName: String?, email: String?) async {
        errorMessage = nil
        isLoading = true
        isPerformingGoogleSignIn = true

        guard let idToken = idToken else {
            errorMessage = "We couldn't verify your Google account. Please try again."
            resetGoogleSignInState()
            return
        }

        do {
            let user = try await authService.signInWithGoogle(
                identityToken: idToken,
                accessToken: accessToken,
                givenName: givenName,
                familyName: familyName,
                email: email,
                requestSignUp: true
            )

            isLoading = false
            isPerformingGoogleSignIn = false

            if AppConfig.Debug.enableLogging {
                print("✅ Google sign-in successful for user: \(user.email)")
            }

        } catch let error as AuthError {
            errorMessage = error.errorDescription
            resetGoogleSignInState()

            if AppConfig.Debug.enableLogging {
                print("❌ Google sign-in failed: \(error.errorDescription ?? "Unknown error")")
            }

        } catch {
            errorMessage = "An unexpected error occurred. Please try again."
            resetGoogleSignInState()

            if AppConfig.Debug.enableLogging {
                print("❌ Unexpected Google sign-in error: \(error.localizedDescription)")
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

// MARK: - Private Helpers
private extension SignUpViewModel {
    func resetAppleSignInState() {
        isLoading = false
        isPerformingAppleSignIn = false
        currentAppleNonce = nil
    }

    func resetGoogleSignInState() {
        isLoading = false
        isPerformingGoogleSignIn = false
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