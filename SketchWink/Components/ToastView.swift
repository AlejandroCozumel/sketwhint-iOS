import SwiftUI

/// Toast notification for success/error feedback
struct ToastView: View {
    let message: String
    let icon: String
    let backgroundColor: Color

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Text(icon)
                .font(.system(size: 24))

            Text(message)
                .font(AppTypography.bodyMedium)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.vertical, AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                .fill(backgroundColor)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal, AppSpacing.md)
    }
}

/// Toast modifier for showing temporary notifications
struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let type: ToastType
    let duration: TimeInterval

    enum ToastType {
        case success
        case error
        case info

        var icon: String {
            switch self {
            case .success: return "✅"
            case .error: return "❌"
            case .info: return "ℹ️"
            }
        }

        var backgroundColor: Color {
            switch self {
            case .success: return AppColors.successGreen
            case .error: return AppColors.errorRed
            case .info: return AppColors.infoBlue
            }
        }
    }

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if isShowing {
                VStack {
                    ToastView(
                        message: message,
                        icon: type.icon,
                        backgroundColor: type.backgroundColor
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                isShowing = false
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.top, 50) // Below navigation bar
                .zIndex(999) // Above all content
            }
        }
    }
}

extension View {
    /// Show success toast notification
    func toast(
        isShowing: Binding<Bool>,
        message: String,
        type: ToastModifier.ToastType = .success,
        duration: TimeInterval = 2.5
    ) -> some View {
        self.modifier(
            ToastModifier(
                isShowing: isShowing,
                message: message,
                type: type,
                duration: duration
            )
        )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: AppSpacing.xl) {
        ToastView(
            message: "Image saved to Photos!",
            icon: "✅",
            backgroundColor: AppColors.successGreen
        )

        ToastView(
            message: "Download failed. Please try again.",
            icon: "❌",
            backgroundColor: AppColors.errorRed
        )

        ToastView(
            message: "Processing your request...",
            icon: "ℹ️",
            backgroundColor: AppColors.infoBlue
        )
    }
    .padding()
    .background(AppColors.backgroundLight)
}
