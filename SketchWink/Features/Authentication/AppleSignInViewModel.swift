import Foundation
import AuthenticationServices

protocol AppleSignInViewModel: ObservableObject {
    var isPerformingAppleSignIn: Bool { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get set }
    
    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest)
    func signInWithApple(using credential: ASAuthorizationAppleIDCredential) async
    func cancelAppleSignInFlow()
}
