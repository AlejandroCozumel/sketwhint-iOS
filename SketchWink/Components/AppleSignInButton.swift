import SwiftUI
import AuthenticationServices

struct AppleSignInButton<ViewModel: AppleSignInViewModel>: View {
    @ObservedObject var viewModel: ViewModel
    var buttonLabel: SignInWithAppleButton.Label

    var body: some View {
        SignInWithAppleButton(
            buttonLabel,
            onRequest: { request in
                viewModel.prepareAppleSignInRequest(request)
            },
            onCompletion: { result in
                switch result {
                case .success(let authorization):
                    if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                        Task {
                            await viewModel.signInWithApple(using: credential)
                        }
                    } else {
                        viewModel.errorMessage = "Unable to process Apple sign-in response."
                        viewModel.cancelAppleSignInFlow()
                    }
                case .failure(let error):
                    if let authError = error as? ASAuthorizationError,
                       authError.code == .canceled {
                        viewModel.cancelAppleSignInFlow()
                        return
                    }
                    viewModel.errorMessage = "Sign in with Apple failed. Please try again."
                    viewModel.cancelAppleSignInFlow()
                }
            }
        )
        .signInWithAppleButtonStyle(.black)
        .frame(maxWidth: .infinity)
        .frame(height: AppSizing.buttonHeight)
        .clipShape(RoundedRectangle(cornerRadius: AppSizing.cornerRadius.round))
        .disabled(viewModel.isPerformingAppleSignIn || viewModel.isLoading)
        .overlay {
            if viewModel.isPerformingAppleSignIn {
                ProgressView()
                    .tint(.white)
            }
        }
    }
}
