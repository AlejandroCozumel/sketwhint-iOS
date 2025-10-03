import SwiftUI

// MARK: - Token Balance Display Component
/// Displays user's current token balance with real-time updates
/// Designed for top-of-app display with child-friendly visual design
struct TokenBalanceView: View {
    
    // MARK: - State
    @StateObject private var tokenManager = TokenBalanceManager.shared
    @State private var showDetailSheet = false
    
    // MARK: - Properties
    let showDetails: Bool
    let compact: Bool
    
    // MARK: - Initialization
    init(showDetails: Bool = true, compact: Bool = false) {
        self.showDetails = showDetails
        self.compact = compact
    }
    
    // MARK: - Body
    var body: some View {
        Group {
            switch tokenManager.loadingState {
            case .idle:
                // Initial state - show placeholder
                placeholderView
                
            case .loading:
                // Loading state with shimmer effect
                loadingView
                
            case .loaded(let tokenBalance):
                // Success state with token information
                tokenBalanceContent(tokenBalance)
                
            case .error(let error):
                // Error state with retry option
                errorView(error)
            }
        }
        .task {
            // Initialize token balance when view appears
            await tokenManager.initialize()
        }
        .sheet(isPresented: $showDetailSheet) {
            TokenBalanceDetailSheet()
        }
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var placeholderView: some View {
        tokenCard {
            HStack(spacing: AppSpacing.sm) {
                tokenIcon
                
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Credits")
                        .font(compact ? AppTypography.captionLarge : AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text("---")
                        .font(compact ? AppTypography.titleSmall : AppTypography.titleMedium)
                        .foregroundColor(AppColors.textPrimary)
                }
                
                Spacer()
                
                if showDetails {
                    infoButton
                }
            }
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        tokenCard {
            HStack(spacing: AppSpacing.sm) {
                // Animated loading icon
                Image(systemName: "creditcard.fill")
                    .font(.system(size: compact ? 18 : 22))
                    .foregroundColor(AppColors.primaryBlue)
                    .symbolEffect(.pulse, isActive: true)
                
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Loading Credits...")
                        .font(compact ? AppTypography.captionLarge : AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                    
                    // Shimmer loading bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.textSecondary.opacity(0.3))
                        .frame(width: compact ? 40 : 60, height: compact ? 16 : 20)
                        .shimmer()
                }
                
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private func tokenBalanceContent(_ balance: TokenBalanceResponse) -> some View {
        beautifulTokenCard {
            HStack(spacing: AppSpacing.md) {
                // Sparkle icon back on the left
                compactTokenIcon
                
                // Two-row aligned layout
                VStack(spacing: 2) {
                    // Top row: My Credits <-> Plan Name
                    HStack {
                        Text("My Credits")
                            .font(AppTypography.captionLarge)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.primaryBlue)

                        Spacer()

                        HStack(spacing: AppSpacing.sm) {
                            // Show plan name (including Free)
                            let parts = splitPlanName(balance.permissions.planName)
                            Text(parts.0)
                                .font(AppTypography.captionLarge)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.primaryBlue)

                            // Warning indicator for low tokens
                            if balance.totalTokens <= 5 && balance.totalTokens > 0 {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppColors.warningOrange)
                                    .accessibilityLabel("Low credits warning")
                            }
                        }
                    }
                    
                    // Bottom row: Number + tokens available <-> Yearly
                    HStack {
                        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                            Text(balance.displayTotalTokens)
                                .font(AppTypography.titleMedium)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.primaryPurple)
                            
                            Text("tokens available")
                                .font(AppTypography.captionSmall)
                                .fontWeight(.regular)
                                .foregroundColor(AppColors.textSecondary.opacity(0.8))
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        if !balance.permissions.planName.lowercased().contains("free") {
                            let parts = splitPlanName(balance.permissions.planName)
                            if !parts.1.isEmpty {
                                Text(parts.1)
                                    .font(AppTypography.captionSmall)
                                    .fontWeight(.medium)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle()) // Make entire card tappable
        .onTapGesture {
            if showDetails {
                showDetailSheet = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Credits: \(balance.totalTokens)")
        .accessibilityHint(showDetails ? "Tap for details" : "")
    }
    
    @ViewBuilder
    private func errorView(_ error: TokenBalanceError) -> some View {
        tokenCard {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: compact ? 18 : 22))
                    .foregroundColor(AppColors.errorRed)
                
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Credits Error")
                        .font(compact ? AppTypography.captionLarge : AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text("Tap to retry")
                        .font(compact ? AppTypography.titleSmall : AppTypography.titleMedium)
                        .foregroundColor(AppColors.errorRed)
                }
                
                Spacer()
                
                Button("Retry") {
                    Task {
                        await tokenManager.refresh()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(AppColors.primaryBlue)
            }
        }
        .onTapGesture {
            Task {
                await tokenManager.refresh()
            }
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private var tokenIcon: some View {
        Image(systemName: "creditcard.fill")
            .font(.system(size: compact ? 18 : 22))
            .foregroundColor(AppColors.primaryBlue)
            .accessibilityHidden(true)
    }
    
    @ViewBuilder
    private var tokenIconWithBackground: some View {
        Image(systemName: "sparkles")
            .font(.system(size: compact ? 20 : 26, weight: .medium))
            .foregroundColor(.white)
            .frame(width: compact ? 36 : 44, height: compact ? 36 : 44)
            .background(
                Circle()
                    .fill(AppColors.primaryBlue)
                    .shadow(color: AppColors.primaryBlue.opacity(0.3), radius: compact ? 2 : 4, x: 0, y: 1)
            )
            .accessibilityHidden(true)
    }
    
    @ViewBuilder
    private var compactTokenIcon: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(.white)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(AppColors.primaryBlue)
                    .shadow(color: AppColors.primaryBlue.opacity(0.2), radius: 2, x: 0, y: 1)
            )
            .accessibilityHidden(true)
    }
    
    @ViewBuilder
    private var infoButton: some View {
        Button {
            showDetailSheet = true
        } label: {
            Image(systemName: "info.circle.fill")
                .font(.system(size: compact ? 14 : 16))
                .foregroundColor(AppColors.primaryBlue.opacity(0.7))
        }
        .childSafeTouchTarget()
        .accessibilityLabel("Credit details")
    }
    
    @ViewBuilder
    private var modernInfoButton: some View {
        Button {
            showDetailSheet = true
        } label: {
            Image(systemName: "chevron.right.circle.fill")
                .font(.system(size: compact ? 18 : 22))
                .foregroundColor(AppColors.primaryBlue.opacity(0.8))
        }
        .childSafeTouchTarget()
        .accessibilityLabel("Credit details")
    }
    
    @ViewBuilder
    private func planBadge(_ planName: String) -> some View {
        Text(planName.uppercased())
            .font(AppTypography.captionSmall)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, 2)
            .background(AppColors.primaryBlue, in: Capsule())
            .accessibilityLabel("Plan: \(planName)")
    }
    
    @ViewBuilder
    private func modernPlanBadge(_ planName: String) -> some View {
        Text("PRO")
            .font(AppTypography.captionSmall)
            .fontWeight(.bold)
            .foregroundColor(AppColors.primaryBlue)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, 2)
            .background(AppColors.primaryBlue.opacity(0.1), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(AppColors.primaryBlue.opacity(0.2), lineWidth: 1)
            )
            .accessibilityLabel("Plan: \(planName)")
    }
    
    @ViewBuilder
    private func planNameDisplay(_ planName: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            // Split plan name into two parts
            let parts = splitPlanName(planName)
            
            Text(parts.0)
                .font(AppTypography.captionLarge)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.primaryBlue)
            
            if !parts.1.isEmpty {
                Text(parts.1)
                    .font(AppTypography.captionSmall)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .multilineTextAlignment(.trailing)
        .accessibilityLabel("Plan: \(planName)")
    }
    
    @ViewBuilder
    private func compactPlanNameDisplay(_ planName: String) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            // Split plan name into two parts
            let parts = splitPlanName(planName)
            
            Text(parts.0)
                .font(AppTypography.captionLarge)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.primaryBlue)
            
            if !parts.1.isEmpty {
                Text(parts.1)
                    .font(AppTypography.captionSmall)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .multilineTextAlignment(.trailing)
        .accessibilityLabel("Plan: \(planName)")
    }
    
    // Helper function to split plan name intelligently
    private func splitPlanName(_ planName: String) -> (String, String) {
        // Remove parentheses and split intelligently
        let cleanName = planName.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
        
        // Common patterns to split on
        if cleanName.lowercased().contains("yearly") {
            let parts = cleanName.components(separatedBy: " ")
            let mainPart = parts.dropLast().joined(separator: " ")
            let timePart = parts.last ?? ""
            return (mainPart.isEmpty ? cleanName : mainPart, timePart)
        } else if cleanName.lowercased().contains("monthly") {
            let parts = cleanName.components(separatedBy: " ")
            let mainPart = parts.dropLast().joined(separator: " ")
            let timePart = parts.last ?? ""
            return (mainPart.isEmpty ? cleanName : mainPart, timePart)
        } else {
            // For other plans, try to split at reasonable points
            let words = cleanName.components(separatedBy: " ")
            if words.count >= 2 {
                let midPoint = words.count / 2
                let firstPart = words[0..<midPoint].joined(separator: " ")
                let secondPart = words[midPoint...].joined(separator: " ")
                return (firstPart, secondPart)
            }
        }
        
        return (cleanName, "")
    }
    
    @ViewBuilder
    private func tokenCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(compact ? AppSpacing.sm : AppSpacing.md)
            .background(AppColors.surfaceLight)
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 8 : 12)
                    .stroke(AppColors.borderLight, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: compact ? 8 : 12))
            .shadow(color: AppColors.primaryBlue.opacity(0.1), radius: compact ? 2 : 4, x: 0, y: compact ? 1 : 2)
    }
    
    @ViewBuilder
    private func beautifulTokenCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, compact ? AppSpacing.md : AppSpacing.lg)
            .padding(.vertical, compact ? AppSpacing.sm : AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: compact ? 12 : 14)
                    .fill(AppColors.surfaceLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: compact ? 12 : 14)
                            .stroke(AppColors.primaryBlue.opacity(0.1), lineWidth: 1)
                    )
            )
            .shadow(
                color: AppColors.primaryBlue.opacity(0.06),
                radius: compact ? 3 : 6,
                x: 0,
                y: compact ? 1 : 3
            )
    }
    
    // MARK: - Helper Methods
    
    private func tokenTextColor(for tokenCount: Int) -> Color {
        switch tokenCount {
        case 0:
            return AppColors.errorRed
        case 1...5:
            return AppColors.warningOrange
        default:
            return AppColors.textPrimary
        }
    }
}

// MARK: - Token Balance Detail Sheet
private struct TokenBalanceDetailSheet: View {
    @StateObject private var tokenManager = TokenBalanceManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    if let balance = tokenManager.tokenBalance {
                        tokenBreakdownCard(balance)
                        subscriptionInfoCard(balance)
                        permissionsCard(balance.permissions)
                    } else {
                        Text("Loading credit details...")
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(AppSpacing.md)
            }
            .navigationTitle("Credit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.primaryBlue)
                }
            }
        }
    }
    
    @ViewBuilder
    private func tokenBreakdownCard(_ balance: TokenBalanceResponse) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Credit Breakdown")
                .font(AppTypography.headlineSmall)
                .foregroundColor(AppColors.textPrimary)
            
            VStack(spacing: AppSpacing.sm) {
                detailRow("Subscription Credits", value: "\(balance.subscriptionTokens)")
                detailRow("Purchased Credits", value: "\(balance.purchasedTokens)")
                
                Divider()
                
                detailRow("Total Available", value: "\(balance.totalTokens)")
                    .font(AppTypography.titleMedium)
                    .fontWeight(.semibold)
            }
        }
        .cardStyle()
    }
    
    @ViewBuilder
    private func subscriptionInfoCard(_ balance: TokenBalanceResponse) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Subscription Info")
                .font(AppTypography.headlineSmall)
                .foregroundColor(AppColors.textPrimary)
            
            VStack(spacing: AppSpacing.sm) {
                detailRow("Current Plan", value: balance.currentPlan)
                detailRow("Account Type", value: balance.permissions.accountType.capitalized)
                detailRow("Max Rollover", value: "\(balance.maxRollover) credits")
                
                if let refreshDate = balance.lastSubscriptionRefresh {
                    detailRow("Last Refresh", value: formatDate(refreshDate))
                }
            }
        }
        .cardStyle()
    }
    
    @ViewBuilder
    private func permissionsCard(_ permissions: UserPermissions) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Account Features")
                .font(AppTypography.headlineSmall)
                .foregroundColor(AppColors.textPrimary)
            
            VStack(spacing: AppSpacing.sm) {
                featureRow("Quality Options", enabled: permissions.hasQualitySelector)
                featureRow("AI Model Selection", enabled: permissions.hasModelSelector)
                featureRow("Commercial License", enabled: permissions.hasCommercialLicense)
                featureRow("Image Upload", enabled: permissions.hasImageUpload)
                
                detailRow("Max Images per Generation", value: "\(permissions.maxImagesPerGeneration)")
                detailRow("Max Family Profiles", value: "\(permissions.maxFamilyProfiles)")
            }
        }
        .cardStyle()
    }
    
    @ViewBuilder
    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textPrimary)
        }
    }
    
    @ViewBuilder
    private func featureRow(_ label: String, enabled: Bool) -> some View {
        HStack {
            Text(label)
                .font(AppTypography.bodyMedium)
                .foregroundColor(AppColors.textSecondary)
            
            Spacer()
            
            Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(enabled ? AppColors.successGreen : AppColors.errorRed)
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - Shimmer Effect Extension
extension View {
    func shimmer() -> some View {
        self.overlay(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.4),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .rotationEffect(.degrees(10))
                .offset(x: -200)
                .animation(
                    .linear(duration: 1.5).repeatForever(autoreverses: false),
                    value: true
                )
        )
        .clipped()
    }
}

// MARK: - Preview
#Preview("Token Balance View") {
    VStack(spacing: 20) {
        Text("Token Balance Components")
            .font(AppTypography.headlineMedium)
        
        TokenBalanceView(showDetails: true, compact: false)
        TokenBalanceView(showDetails: true, compact: true)
        TokenBalanceView(showDetails: false, compact: true)
    }
    .padding()
    .background(AppColors.backgroundLight)
}