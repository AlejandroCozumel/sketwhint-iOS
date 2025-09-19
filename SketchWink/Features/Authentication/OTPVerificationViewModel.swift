import Foundation
import SwiftUI
import Combine

@MainActor
class OTPVerificationViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSuccessAlert = false
    @Published var showSuccessMessage = false
    @Published var showSuccessToast = false
    @Published var shouldNavigateToMainApp = false
    @Published var canResendOTP = false
    @Published var resendCountdown = 60
    
    private let authService = AuthService.shared
    private var resendTimer: Timer?
    
    // MARK: - Verify OTP
    func verifyOTP(email: String, code: String) async {
        // Reset previous state
        errorMessage = nil
        isLoading = true
        
        // Validate input
        guard code.count == 6, code.allSatisfy({ $0.isNumber }) else {
            errorMessage = "Please enter a valid 6-digit code"
            isLoading = false
            return
        }
        
        do {
            let response = try await authService.verifyOTP(email: email, code: code)
            
            if response.success, let user = response.user, let session = response.session {
                // Success - show toast and authenticate after delay
                showSuccessToast = true
                isLoading = false
                
                // Log success for debugging
                if AppConfig.Debug.enableLogging {
                    print("✅ OTP verification successful for: \(email)")
                    print("🔑 User authenticated with session token")
                }
                
                // Store session token securely first
                do {
                    try KeychainManager.shared.storeToken(session.token)
                } catch {
                    if AppConfig.Debug.enableLogging {
                        print("⚠️ Failed to store token in keychain: \(error)")
                    }
                }
                
                // Authenticate user after showing success toast for 1.5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.authService.currentUser = user
                    self.authService.isAuthenticated = true
                    // This will trigger AppCoordinator to show MainAppView
                }
                
            } else {
                errorMessage = response.message
                isLoading = false
            }
            
        } catch let error as AuthError {
            // Use the actual backend error message
            errorMessage = error.errorDescription
            isLoading = false
            
            // Log error for debugging
            if AppConfig.Debug.enableLogging {
                print("❌ OTP verification failed: \(error.errorDescription ?? "Unknown error")")
            }
            
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            
            // Log unexpected errors
            if AppConfig.Debug.enableLogging {
                print("❌ Unexpected OTP verification error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Resend OTP
    func resendOTP(email: String) async {
        // Reset previous state
        errorMessage = nil
        showSuccessMessage = false
        
        do {
            let response = try await authService.resendOTP(email: email)
            
            if response.success {
                // Success - show success message and restart timer
                showSuccessMessage = true
                startResendTimer()
                
                // Log success for debugging
                if AppConfig.Debug.enableLogging {
                    print("✅ OTP resent successfully to: \(email)")
                }
                
                // Hide success message after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.showSuccessMessage = false
                }
                
            } else {
                errorMessage = response.message.isEmpty ? "Failed to resend code. Please try again." : response.message
            }
            
        } catch let error as AuthError {
            errorMessage = error.errorDescription
            
            // Log error for debugging
            if AppConfig.Debug.enableLogging {
                print("❌ OTP resend failed: \(error.errorDescription ?? "Unknown error")")
            }
            
        } catch {
            errorMessage = "An unexpected error occurred. Please try again."
            
            // Log unexpected errors
            if AppConfig.Debug.enableLogging {
                print("❌ Unexpected OTP resend error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Timer Management
    func startResendTimer() {
        canResendOTP = false
        resendCountdown = 60
        
        resendTimer?.invalidate()
        resendTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if self.resendCountdown > 0 {
                    self.resendCountdown -= 1
                } else {
                    self.canResendOTP = true
                    self.resendTimer?.invalidate()
                    self.resendTimer = nil
                }
            }
        }
    }
    
    // MARK: - Navigation
    func navigateToMainApp() {
        // User is now authenticated, navigate to main app
        // This will dismiss all authentication views since user is authenticated
        shouldNavigateToMainApp = true
        
        if AppConfig.Debug.enableLogging {
            print("✅ User authenticated, navigating to main app")
        }
    }
    
    // MARK: - Clear Error
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Cleanup
    deinit {
        resendTimer?.invalidate()
    }
    
    // MARK: - Demo Methods (for testing)
    #if DEBUG
    func verifyWithDemoCode() async {
        await verifyOTP(email: "demo@sketchwink.com", code: "123456")
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
    
    func simulateSuccess() {
        showSuccessMessage = true
        
        // Hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.showSuccessMessage = false
        }
    }
    #endif
}

// MARK: - Validation Helpers
extension OTPVerificationViewModel {
    
    /// Validates OTP code format
    func isValidOTPCode(_ code: String) -> Bool {
        return code.count == 6 && code.allSatisfy { $0.isNumber }
    }
    
    /// Returns OTP validation message
    func otpValidationMessage(for code: String) -> String? {
        guard !code.isEmpty else { return nil }
        guard isValidOTPCode(code) else {
            return "Please enter a valid 6-digit code"
        }
        return nil
    }
    
    /// Formats email for display (truncates if too long)
    func formatEmailForDisplay(_ email: String) -> String {
        if email.count <= 30 {
            return email
        }
        
        let components = email.components(separatedBy: "@")
        guard components.count == 2 else { return email }
        
        let username = components[0]
        let domain = components[1]
        
        if username.count > 10 {
            let truncatedUsername = String(username.prefix(7)) + "..."
            return "\(truncatedUsername)@\(domain)"
        }
        
        return email
    }
}