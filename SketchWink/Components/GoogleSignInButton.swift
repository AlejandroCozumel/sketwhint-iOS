import SwiftUI

struct GoogleSignInButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Image("google-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)

                Text("Continue with Google")
                    .font(AppTypography.buttonText)
                    .foregroundColor(Color(red: 0.12, green: 0.12, blue: 0.12)) // #1f1f1f
            }
            .frame(maxWidth: .infinity)
            .frame(height: AppSizing.buttonHeight)
        }
        .background(Color.white)
        .cornerRadius(AppSizing.cornerRadius.round)
        .overlay(
            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.round)
                .stroke(Color(red: 0.91, green: 0.91, blue: 0.91), lineWidth: 1) // #e8e8e8
        )
    }
}
