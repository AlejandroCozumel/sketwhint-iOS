import SwiftUI

struct SubscriptionPlansView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBillingCycle: BillingCycle = .monthly
    @State private var selectedPlan: SubscriptionPlan?
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let highlightedFeature: String?
    let currentPlan: String?
    
    init(highlightedFeature: String? = nil, currentPlan: String? = nil) {
        self.highlightedFeature = highlightedFeature
        self.currentPlan = currentPlan
    }
    
    enum BillingCycle: String, CaseIterable {
        case monthly = "Monthly"
        case yearly = "Yearly"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.sectionSpacing) {
                    
                    // Header Section
                    headerSection
                    
                    // Billing Cycle Toggle
                    billingCycleToggle
                    
                    // Plans Grid
                    plansGrid
                    
                    // Selected Plan Features (Dynamic)
                    selectedPlanFeatures
                    
                    // Bottom Information
                    bottomInfo
                }
                .pageMargins()
                .padding(.vertical, AppSpacing.sectionSpacing)
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("Upgrade Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.primaryBlue)
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: AppSpacing.lg) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.primaryPurple, AppColors.primaryBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .shadow(
                        color: AppColors.primaryPurple.opacity(0.3),
                        radius: AppSizing.shadows.large.radius,
                        x: AppSizing.shadows.large.x,
                        y: AppSizing.shadows.large.y
                    )
                
                Text("✨")
                    .font(.system(size: 60))
            }
            
            VStack(spacing: AppSpacing.sm) {
                Text("Unlock Premium Features")
                    .displayMedium()
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                if let feature = highlightedFeature {
                    Text("Get access to \(feature) and much more!")
                        .bodyMedium()
                        .foregroundColor(AppColors.primaryBlue)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(AppColors.primaryBlue.opacity(0.1))
                        .cornerRadius(AppSizing.cornerRadius.md)
                } else {
                    Text("Create unlimited art with AI and unlock advanced features")
                        .bodyMedium()
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .contentPadding()
    }
    
    // MARK: - Billing Cycle Toggle
    private var billingCycleToggle: some View {
        VStack(spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(BillingCycle.allCases, id: \.self) { cycle in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedBillingCycle = cycle
                        }
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            Text(cycle.rawValue)
                                .font(AppTypography.titleMedium)
                                .foregroundColor(selectedBillingCycle == cycle ? .white : AppColors.textPrimary)
                            
                            if cycle == .yearly {
                                Text("SAVE 20%")
                                    .font(AppTypography.captionSmall)
                                    .fontWeight(.bold)
                                    .foregroundColor(selectedBillingCycle == cycle ? .white : AppColors.successGreen)
                                    .padding(.horizontal, AppSpacing.xs)
                                    .padding(.vertical, 2)
                                    .background(
                                        selectedBillingCycle == cycle ? 
                                        Color.white.opacity(0.3) : 
                                        AppColors.successGreen.opacity(0.2)
                                    )
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.md)
                        .background(
                            selectedBillingCycle == cycle ? 
                            AppColors.primaryBlue : 
                            AppColors.backgroundLight
                        )
                        .cornerRadius(AppSizing.cornerRadius.lg)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                                .stroke(
                                    selectedBillingCycle == cycle ? 
                                    AppColors.primaryBlue : 
                                    AppColors.borderMedium,
                                    lineWidth: 1
                                )
                        )
                    }
                    .childSafeTouchTarget()
                }
            }
        }
        .cardStyle()
    }
    
    // MARK: - Plans Grid
    private var plansGrid: some View {
        LazyVGrid(columns: GridLayouts.categoryGrid, spacing: AppSpacing.grid.rowSpacing) {
            ForEach(mockSubscriptionPlans) { plan in
                SubscriptionPlanCard(
                    plan: plan,
                    billingCycle: selectedBillingCycle,
                    isCurrentPlan: plan.id == currentPlan,
                    isSelected: selectedPlan?.id == plan.id,
                    isHighlighted: plan.isPopular,
                    onSelect: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedPlan = plan
                        }
                    },
                    onPurchase: {
                        purchasePlan(plan)
                    }
                )
            }
        }
        .onAppear {
            // Auto-select the popular plan by default
            if selectedPlan == nil {
                selectedPlan = mockSubscriptionPlans.first { $0.isPopular } ?? mockSubscriptionPlans.first
            }
        }
    }
    
    // MARK: - Selected Plan Features
    private var selectedPlanFeatures: some View {
        Group {
            if let plan = selectedPlan {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("\(plan.displayName) Plan")
                                .headlineLarge()
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("Everything you get with \(plan.displayName)")
                                .bodyMedium()
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        // Price display
                        VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                                Text(selectedBillingCycle == .monthly ? plan.monthlyPriceString : plan.yearlyPriceString)
                                    .font(AppTypography.headlineLarge)
                                    .fontWeight(.bold)
                                    .foregroundColor(planColor(for: plan))
                                
                                if !plan.isFree {
                                    Text(selectedBillingCycle == .monthly ? "/month" : "/year")
                                        .font(AppTypography.captionMedium)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }
                            
                            if selectedBillingCycle == .yearly && !plan.isFree, let savings = plan.monthlySavings {
                                Text(savings)
                                    .font(AppTypography.captionSmall)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.successGreen)
                                    .padding(.horizontal, AppSpacing.xs)
                                    .padding(.vertical, 2)
                                    .background(AppColors.successGreen.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    
                    // Features Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: AppSpacing.md) {
                        PlanFeatureCard(
                            icon: "photo.stack",
                            title: "Monthly Images",
                            value: "\(plan.monthlyTokens)",
                            subtitle: "AI generations",
                            color: planColor(for: plan)
                        )
                        
                        PlanFeatureCard(
                            icon: "rectangle.stack",
                            title: "Images per Generation",
                            value: "Up to \(plan.maxImagesPerGeneration)",
                            subtitle: "variations",
                            color: planColor(for: plan)
                        )
                        
                        PlanFeatureCard(
                            icon: "sparkles",
                            title: "Quality Options",
                            value: plan.hasQualitySelector ? "All Qualities" : "Standard",
                            subtitle: plan.hasQualitySelector ? "standard, high, ultra" : "fast generation",
                            color: planColor(for: plan)
                        )
                        
                        PlanFeatureCard(
                            icon: "brain.head.profile",
                            title: "AI Models",
                            value: plan.hasModelSelector ? "Multiple Models" : "Seedream",
                            subtitle: plan.hasModelSelector ? "seedream, flux" : "family-friendly",
                            color: planColor(for: plan)
                        )
                    }
                    
                    // Full features list
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Complete Feature List")
                            .titleMedium()
                            .foregroundColor(AppColors.textPrimary)
                        
                        LazyVGrid(columns: [GridItem(.flexible())], spacing: AppSpacing.xs) {
                            ForEach(plan.features, id: \.self) { feature in
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(AppColors.successGreen)
                                    
                                    Text(feature)
                                        .font(AppTypography.bodyMedium)
                                        .foregroundColor(AppColors.textPrimary)
                                    
                                    Spacer()
                                }
                            }
                        }
                    }
                    
                    // Purchase button
                    Button {
                        purchasePlan(plan)
                    } label: {
                        Group {
                            if plan.id == currentPlan {
                                Text("Current Plan")
                            } else if plan.isFree {
                                Text("Continue with Free")
                            } else {
                                Text("Upgrade to \(plan.displayName) - \(selectedBillingCycle == .monthly ? plan.monthlyPriceString : plan.yearlyPriceString)\(selectedBillingCycle == .monthly ? "/month" : "/year")")
                            }
                        }
                        .font(AppTypography.titleMedium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            plan.id == currentPlan ? 
                            AppColors.textSecondary : 
                            planColor(for: plan)
                        )
                        .cornerRadius(AppSizing.cornerRadius.lg)
                    }
                    .disabled(plan.id == currentPlan)
                    .childSafeTouchTarget()
                }
                .cardStyle()
            }
        }
    }
    
    private func planColor(for plan: SubscriptionPlan) -> Color {
        if let colorHex = plan.color {
            return Color(hex: colorHex)
        }
        switch plan.id {
        case "free": return AppColors.textSecondary
        case "basic": return AppColors.primaryBlue
        case "pro": return AppColors.primaryPurple
        case "max": return AppColors.primaryPink
        default: return AppColors.primaryBlue
        }
    }
    
    // MARK: - Bottom Info
    private var bottomInfo: some View {
        VStack(spacing: AppSpacing.md) {
            VStack(spacing: AppSpacing.xs) {
                Text("🔒 Secure Payment")
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.textPrimary)
                
                Text("Powered by Apple In-App Purchase. Cancel anytime.")
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: AppSpacing.lg) {
                Button("Privacy Policy") {
                    // TODO: Open privacy policy
                }
                .font(AppTypography.captionLarge)
                .foregroundColor(AppColors.primaryBlue)
                
                Button("Terms of Service") {
                    // TODO: Open terms of service
                }
                .font(AppTypography.captionLarge)
                .foregroundColor(AppColors.primaryBlue)
                
                Button("Restore Purchases") {
                    // TODO: Restore purchases
                }
                .font(AppTypography.captionLarge)
                .foregroundColor(AppColors.primaryBlue)
            }
        }
        .contentPadding()
    }
    
    // MARK: - Actions
    private func purchasePlan(_ plan: SubscriptionPlan) {
        isLoading = true
        
        // TODO: Implement Apple In-App Purchase logic
        #if DEBUG
        print("🛒 Purchasing plan: \(plan.displayName)")
        print("🛒 Billing cycle: \(selectedBillingCycle.rawValue)")
        #endif
        
        // Simulate purchase process
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isLoading = false
            // For now, just show success or error
            errorMessage = "Purchase functionality will be implemented with Apple In-App Purchase"
            showingError = true
        }
    }
}

// MARK: - Plan Feature Card
struct PlanFeatureCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(color)
            
            VStack(spacing: AppSpacing.xs) {
                Text(value)
                    .font(AppTypography.titleMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(title)
                    .font(AppTypography.captionMedium)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .font(AppTypography.captionSmall)
                    .foregroundColor(color.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(color.opacity(0.05))
        .cornerRadius(AppSizing.cornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Subscription Plan Card
struct SubscriptionPlanCard: View {
    let plan: SubscriptionPlan
    let billingCycle: SubscriptionPlansView.BillingCycle
    let isCurrentPlan: Bool
    let isSelected: Bool
    let isHighlighted: Bool
    let onSelect: () -> Void
    let onPurchase: () -> Void
    
    private var displayPrice: String {
        switch billingCycle {
        case .monthly:
            return plan.monthlyPriceString
        case .yearly:
            return plan.yearlyPriceString
        }
    }
    
    private var priceSubtext: String {
        switch billingCycle {
        case .monthly:
            return "/month"
        case .yearly:
            if let savings = plan.monthlySavings {
                return "/year • \(savings)"
            } else {
                return "/year"
            }
        }
    }
    
    private var cardColor: Color {
        if let colorHex = plan.color {
            return Color(hex: colorHex)
        }
        switch plan.id {
        case "free": return AppColors.textSecondary
        case "basic": return AppColors.primaryBlue
        case "pro": return AppColors.primaryPurple
        case "max": return AppColors.primaryPink
        default: return AppColors.primaryBlue
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: AppSpacing.md) {
            // Header
            VStack(spacing: AppSpacing.sm) {
                if isHighlighted {
                    Text("MOST POPULAR")
                        .font(AppTypography.captionSmall)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                        .background(AppColors.successGreen)
                        .cornerRadius(AppSizing.cornerRadius.sm)
                }
                
                Text(plan.displayName)
                    .font(AppTypography.headlineMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: AppSpacing.xxxs) {
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                        Text(displayPrice)
                            .font(AppTypography.displaySmall)
                            .fontWeight(.bold)
                            .foregroundColor(cardColor)
                        
                        if !plan.isFree {
                            Text(priceSubtext)
                                .font(AppTypography.captionMedium)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    
                    Text("\(plan.monthlyTokens) images/month")
                        .font(AppTypography.captionMedium)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            // Features
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                ForEach(plan.features.prefix(4), id: \.self) { feature in
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.successGreen)
                        
                        Text(feature)
                            .font(AppTypography.captionMedium)
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                }
            }
            
            Spacer()
            
            // Action Button
            Button(action: onPurchase) {
                Group {
                    if isCurrentPlan {
                        Text("Current Plan")
                    } else if plan.isFree {
                        Text("Continue with Free")
                    } else {
                        Text("Upgrade to \(plan.displayName)")
                    }
                }
                .font(AppTypography.titleMedium)
                .foregroundColor(isCurrentPlan ? AppColors.textSecondary : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    isCurrentPlan ? 
                    AppColors.backgroundLight : 
                    cardColor
                )
                .cornerRadius(AppSizing.cornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                        .stroke(
                            isCurrentPlan ? AppColors.borderMedium : Color.clear,
                            lineWidth: 1
                        )
                )
            }
            .disabled(isCurrentPlan)
            .childSafeTouchTarget()
        }
        .padding(AppSpacing.md)
        .frame(height: 280)
        .background(AppColors.backgroundLight)
        .cornerRadius(AppSizing.cornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg)
                .stroke(
                    isSelected ? cardColor : (isHighlighted ? cardColor.opacity(0.5) : AppColors.borderLight),
                    lineWidth: isSelected ? 3 : (isHighlighted ? 2 : 1)
                )
        )
        .shadow(
            color: isSelected ? cardColor.opacity(0.3) : (isHighlighted ? cardColor.opacity(0.2) : Color.black.opacity(0.05)),
            radius: isSelected ? 12 : (isHighlighted ? 8 : 4),
            x: 0,
            y: isSelected ? 4 : 2
        )
        .scaleEffect(isSelected ? 1.05 : (isHighlighted ? 1.02 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .childSafeTouchTarget()
    }
}


// MARK: - Mock Data
private let mockSubscriptionPlans: [SubscriptionPlan] = [
    SubscriptionPlan(
        id: "free",
        name: "free",
        displayName: "Free",
        description: "Perfect for trying out SketchWink",
        monthlyPrice: 0,
        yearlyPrice: 0,
        monthlyTokens: 3,
        features: [
            "3 AI images per month",
            "Standard quality",
            "1 image per generation",
            "Basic support"
        ],
        isPopular: false,
        color: nil,
        maxImagesPerGeneration: 1,
        hasQualitySelector: false,
        hasModelSelector: false,
        availableModels: ["seedream"],
        availableQuality: ["standard"]
    ),
    SubscriptionPlan(
        id: "basic",
        name: "basic",
        displayName: "Basic",
        description: "Great for regular creative projects",
        monthlyPrice: 9.99,
        yearlyPrice: 95.99,
        monthlyTokens: 100,
        features: [
            "100 AI images per month",
            "Standard quality",
            "Up to 4 images per generation",
            "3 family profiles",
            "Priority support"
        ],
        isPopular: true,
        color: "#37B6F6",
        maxImagesPerGeneration: 4,
        hasQualitySelector: false,
        hasModelSelector: false,
        availableModels: ["seedream"],
        availableQuality: ["standard"]
    ),
    SubscriptionPlan(
        id: "pro",
        name: "pro",
        displayName: "Pro",
        description: "Perfect for families and educators",
        monthlyPrice: 19.99,
        yearlyPrice: 191.99,
        monthlyTokens: 300,
        features: [
            "300 AI images per month",
            "Standard quality",
            "Up to 4 images per generation",
            "5 family profiles",
            "Premium support"
        ],
        isPopular: false,
        color: "#882FF6",
        maxImagesPerGeneration: 4,
        hasQualitySelector: false,
        hasModelSelector: false,
        availableModels: ["seedream"],
        availableQuality: ["standard"]
    ),
    SubscriptionPlan(
        id: "max",
        name: "max",
        displayName: "Max",
        description: "Ultimate creative freedom",
        monthlyPrice: 39.99,
        yearlyPrice: 383.99,
        monthlyTokens: 600,
        features: [
            "600 AI images per month",
            "All quality options",
            "Up to 4 images per generation",
            "6 family profiles",
            "Premium support"
        ],
        isPopular: false,
        color: "#FF6B9D",
        maxImagesPerGeneration: 4,
        hasQualitySelector: true,
        hasModelSelector: false,
        availableModels: ["seedream"],
        availableQuality: ["standard", "high", "ultra"]
    )
]

#if DEBUG
struct SubscriptionPlansView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionPlansView(
            highlightedFeature: "Multiple Images",
            currentPlan: "free"
        )
    }
}
#endif