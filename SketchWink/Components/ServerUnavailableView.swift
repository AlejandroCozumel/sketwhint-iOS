import SwiftUI

struct ServerUnavailableView: View {
    let serverStatus: ServerStatus
    let onRetry: () async -> Void
    @State private var isRetrying = false
    
    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            
            // Icon and visual
            VStack(spacing: AppSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(errorColor.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 60, weight: .light))
                        .foregroundColor(errorColor)
                }
                
                VStack(spacing: AppSpacing.sm) {
                    Text(errorTitle)
                        .headlineLarge()
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text(errorDescription)
                        .bodyMedium()
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                }
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: AppSpacing.md) {
                // Retry button
                Button(action: {
                    Task {
                        await retry()
                    }
                }) {
                    HStack {
                        if isRetrying {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        
                        Text(isRetrying ? "Connecting..." : "Try Again")
                            .font(AppTypography.buttonLarge)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppSizing.largeTouchTarget)
                    .background(AppColors.primaryBlue)
                    .cornerRadius(AppSizing.cornerRadius.md)
                    .shadow(
                        color: AppColors.primaryBlue.opacity(0.3),
                        radius: AppSizing.shadows.medium.radius,
                        x: AppSizing.shadows.medium.x,
                        y: AppSizing.shadows.medium.y
                    )
                }
                .disabled(isRetrying)
                .childSafeTouchTarget()
                
                // Troubleshooting tips
                VStack(spacing: AppSpacing.xs) {
                    Text("Troubleshooting Tips:")
                        .font(AppTypography.captionLarge)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textSecondary)
                    
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        ForEach(troubleshootingTips, id: \.self) { tip in
                            TroubleshootingTip(text: tip)
                        }
                    }
                }
                .padding(AppSpacing.md)
                .background(AppColors.surfaceLight)
                .cornerRadius(AppSizing.cornerRadius.sm)
            }
            .contentPadding()
        }
        .background(AppColors.backgroundLight)
        .navigationBarHidden(true)
    }
    
    // MARK: - Computed Properties
    private var errorColor: Color {
        switch serverStatus {
        case .available:
            return AppColors.successGreen
        case .networkError:
            return AppColors.warningOrange
        case .serverDown:
            return AppColors.errorRed
        case .timeout:
            return AppColors.warningOrange
        case .invalidConfiguration:
            return AppColors.errorRed
        }
    }
    
    private var iconName: String {
        switch serverStatus {
        case .available:
            return "checkmark.circle"
        case .networkError:
            return "wifi.slash"
        case .serverDown:
            return "server.rack"
        case .timeout:
            return "clock.arrow.circlepath"
        case .invalidConfiguration:
            return "exclamationmark.triangle"
        }
    }
    
    private var errorTitle: String {
        switch serverStatus {
        case .available:
            return "Connected"
        case .networkError:
            return "No Internet Connection"
        case .serverDown:
            return "Server Unavailable"
        case .timeout:
            return "Connection Timeout"
        case .invalidConfiguration:
            return "Configuration Error"
        }
    }
    
    private var errorDescription: String {
        switch serverStatus {
        case .available:
            return "Everything is working properly."
        case .networkError:
            return "Your device isn't connected to the internet. Please check your WiFi or cellular connection and try again."
        case .serverDown:
            return "SketchWink servers are temporarily unavailable. This might be due to maintenance or high traffic. Please try again in a few minutes."
        case .timeout:
            return "The connection is taking too long. The server might be busy or your connection might be slow. Please try again."
        case .invalidConfiguration:
            return "There's a problem with the app configuration. Please contact support or try reinstalling the app."
        }
    }
    
    private var troubleshootingTips: [String] {
        switch serverStatus {
        case .available:
            return []
        case .networkError:
            return [
                "Check your WiFi connection is working",
                "Try switching between WiFi and cellular data",
                "Move closer to your WiFi router",
                "Restart your internet connection"
            ]
        case .serverDown:
            return [
                "Wait a few minutes and try again",
                "Check if other apps can connect to the internet",
                "The server might be under maintenance",
                "Visit our website for status updates"
            ]
        case .timeout:
            return [
                "Check your internet connection speed",
                "Try again with a better connection",
                "Close other apps that might be using bandwidth",
                "Wait a moment and retry"
            ]
        case .invalidConfiguration:
            return [
                "Restart the app completely",
                "Check if app update is available",
                "Contact support if problem persists",
                "Try reinstalling the app"
            ]
        }
    }
    
    private func retry() async {
        isRetrying = true
        
        // Add a small delay for better UX
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await onRetry()
        
        await MainActor.run {
            isRetrying = false
        }
    }
}

// MARK: - Supporting Views
struct TroubleshootingTip: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            Text("•")
                .font(AppTypography.captionLarge)
                .foregroundColor(AppColors.primaryBlue)
                .frame(width: 12)
            
            Text(text)
                .font(AppTypography.captionLarge)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
    }
}

// MARK: - Preview
#if DEBUG
struct ServerUnavailableView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ServerUnavailableView(
                serverStatus: .networkError("No internet connection"),
                onRetry: {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            )
            .previewDisplayName("Network Error")
            
            ServerUnavailableView(
                serverStatus: .serverDown("Server maintenance"),
                onRetry: {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            )
            .previewDisplayName("Server Down")
            
            ServerUnavailableView(
                serverStatus: .timeout("Connection timeout"),
                onRetry: {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            )
            .previewDisplayName("Timeout")
            
            ServerUnavailableView(
                serverStatus: .invalidConfiguration,
                onRetry: {
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            )
            .previewDisplayName("Config Error")
        }
    }
}
#endif