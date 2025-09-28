import SwiftUI

// MARK: - Network Status Banner
/// Family-friendly network status indicator with retry functionality
struct NetworkStatusBanner: View {
    @StateObject private var authService = AuthService.shared
    @State private var isRetrying = false
    
    var body: some View {
        Group {
            if !authService.isNetworkAvailable {
                VStack(spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.sm) {
                        statusIcon
                        
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(statusTitle)
                                .font(AppTypography.titleSmall)
                                .foregroundColor(AppColors.textOnDark)
                                .fontWeight(.semibold)
                            
                            Text(statusMessage)
                                .font(AppTypography.captionLarge)
                                .foregroundColor(AppColors.textOnDark.opacity(0.9))
                                .multilineTextAlignment(.leading)
                        }
                        
                        Spacer()
                        
                        retryButton
                    }
                    .padding(AppSpacing.md)
                    .background(statusColor, in: RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md))
                    .shadow(
                        color: statusColor.opacity(0.3),
                        radius: AppSizing.shadows.medium.radius,
                        x: AppSizing.shadows.medium.x,
                        y: AppSizing.shadows.medium.y
                    )
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: authService.isNetworkAvailable)
            }
        }
    }
    
    // MARK: - Status Components
    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Image(systemName: statusIconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
        }
    }
    
    private var retryButton: some View {
        Button(action: {
            Task {
                await retryConnection()
            }
        }) {
            HStack(spacing: AppSpacing.xs) {
                if isRetrying {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                }
                
                Text(isRetrying ? "Checking..." : "Retry")
                    .font(AppTypography.captionLarge)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(.white.opacity(0.2), in: Capsule())
            .foregroundColor(.white)
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isRetrying)
        .childSafeTouchTarget()
    }
    
    // MARK: - Status Properties
    private var statusColor: Color {
        switch authService.networkStatus {
        case .connected:
            return AppColors.successGreen
        case .serverUnavailable:
            return AppColors.warningOrange
        case .networkError:
            return AppColors.errorRed
        case .timeout:
            return AppColors.infoBlue
        }
    }
    
    private var statusIconName: String {
        switch authService.networkStatus {
        case .connected:
            return "checkmark.circle.fill"
        case .serverUnavailable:
            return "server.rack"
        case .networkError:
            return "wifi.slash"
        case .timeout:
            return "clock.arrow.circlepath"
        }
    }
    
    private var statusTitle: String {
        switch authService.networkStatus {
        case .connected:
            return "Connected"
        case .serverUnavailable:
            return "Server Unavailable"
        case .networkError:
            return "Connection Issue"
        case .timeout:
            return "Slow Connection"
        }
    }
    
    private var statusMessage: String {
        switch authService.networkStatus {
        case .connected:
            return "Everything is working normally"
        case .serverUnavailable:
            return "You can still view your saved creations"
        case .networkError:
            return "Check your internet connection"
        case .timeout:
            return "The connection is taking longer than usual"
        }
    }
    
    // MARK: - Actions
    private func retryConnection() async {
        guard !isRetrying else { return }
        
        await MainActor.run {
            isRetrying = true
        }
        
        // Add a small delay for better UX
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await authService.retryAuthenticationCheck()
        
        await MainActor.run {
            isRetrying = false
        }
    }
}

// MARK: - Network Status Indicator (Compact)
/// Small network status indicator for navigation bars
struct NetworkStatusIndicator: View {
    @StateObject private var authService = AuthService.shared
    
    var body: some View {
        Group {
            if !authService.isNetworkAvailable {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: statusIconName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(statusColor)
                    
                    Text(statusTitle)
                        .font(AppTypography.captionSmall)
                        .foregroundColor(statusColor)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(statusColor.opacity(0.1), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(statusColor.opacity(0.3), lineWidth: 1)
                )
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: authService.isNetworkAvailable)
            }
        }
    }
    
    private var statusColor: Color {
        switch authService.networkStatus {
        case .connected:
            return AppColors.successGreen
        case .serverUnavailable:
            return AppColors.warningOrange
        case .networkError:
            return AppColors.errorRed
        case .timeout:
            return AppColors.infoBlue
        }
    }
    
    private var statusIconName: String {
        switch authService.networkStatus {
        case .connected:
            return "checkmark.circle.fill"
        case .serverUnavailable:
            return "server.rack"
        case .networkError:
            return "wifi.slash"
        case .timeout:
            return "clock"
        }
    }
    
    private var statusTitle: String {
        switch authService.networkStatus {
        case .connected:
            return "Online"
        case .serverUnavailable:
            return "Server Down"
        case .networkError:
            return "Offline"
        case .timeout:
            return "Slow"
        }
    }
}

// MARK: - Preview
#if DEBUG
struct NetworkStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppSpacing.lg) {
            // Preview different states
            NetworkStatusBanner()
                .onAppear {
                    AuthService.shared.networkStatus = .serverUnavailable
                }
            
            NetworkStatusBanner()
                .onAppear {
                    AuthService.shared.networkStatus = .networkError
                }
            
            NetworkStatusIndicator()
                .onAppear {
                    AuthService.shared.networkStatus = .timeout
                }
        }
        .padding()
        .background(AppColors.backgroundLight)
        .previewDisplayName("Network Status Components")
    }
}
#endif