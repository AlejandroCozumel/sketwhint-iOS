import SwiftUI

/// Toast notification for success/error feedback
struct ToastView: View {
    let message: String
    let icon: String
    let type: ToastModifier.ToastType

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Icon Container
            ZStack {
                Circle()
                    .fill(type.backgroundColor.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(type.backgroundColor)
            }
            
            Text(message)
                .font(AppTypography.bodyMedium)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.xl) // More rounded
                .fill(AppColors.surfaceLight)
                .shadow(color: type.backgroundColor.opacity(0.15), radius: 12, x: 0, y: 6) // Colored shadow
                .overlay(
                    RoundedRectangle(cornerRadius: AppSizing.cornerRadius.xl)
                        .stroke(type.backgroundColor.opacity(0.2), lineWidth: 1) // Subtle border
                )
        )
        .padding(.horizontal, AppSpacing.lg)
    }
}

/// Toast modifier for showing temporary notifications
struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let type: ToastType
    let duration: TimeInterval = 3.0 // Slightly longer for better readability

    enum ToastType {
        case success
        case error
        case info

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.circle.fill"
            case .info: return "info.circle.fill"
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
                        type: type
                    )
                    .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.95)))
                    .onAppear {
                        // Haptic feedback
                        if type == .success {
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        } else if type == .error {
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.error)
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                isShowing = false
                            }
                        }
                    }
                    .padding(.top, 8) // Small padding from top
                    
                    Spacer()
                }
                .zIndex(999) // Above all content
            }
        }
    }
}

extension View {
    /// Show toast notification
    func toast(
        isShowing: Binding<Bool>,
        message: String,
        type: ToastModifier.ToastType = .success
    ) -> some View {
        self.modifier(
            ToastModifier(
                isShowing: isShowing,
                message: message,
                type: type
            )
        )
    }
}

// MARK: - Preview
#if DEBUG
struct ToastView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AppColors.backgroundLight.ignoresSafeArea()
            
            VStack(spacing: AppSpacing.xl) {
                ToastView(
                    message: "Story generated successfully!",
                    icon: "checkmark.circle.fill",
                    type: .success
                )
                
                ToastView(
                    message: "Something went wrong. Please try again.",
                    icon: "exclamationmark.circle.fill",
                    type: .error
                )
                
                ToastView(
                    message: "Generating your masterpiece...",
                    icon: "info.circle.fill",
                    type: .info
                )
            }
            .padding()
        }
    }
}
#endif
