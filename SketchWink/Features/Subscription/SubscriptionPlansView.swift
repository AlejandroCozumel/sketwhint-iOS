import SwiftUI

struct SubscriptionPlansView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tokenManager = TokenBalanceManager.shared
    @State private var currentPlanIndex = 1 // Start at Basic plan
    @State private var isYearly = true // Default to yearly for better value
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""

    // Plan data - from backend seed database
    private let plans = [
        PlanCard(
            id: "basic",
            name: "Basic",
            monthlyTokens: 50,
            monthlyPrice: 9,
            yearlyPrice: 90,
            color: AppColors.primaryBlue,
            icon: "paintbrush.fill",
            features: [
                "50 credits every month",
                "All art categories",
                "3-month credit rollover",
                "Cancel anytime"
            ]
        ),
        PlanCard(
            id: "pro",
            name: "Pro",
            monthlyTokens: 120,
            monthlyPrice: 18,
            yearlyPrice: 180,
            color: AppColors.primaryPurple,
            icon: "star.fill",
            features: [
                "120 credits every month",
                "Up to 5 family profiles",
                "PIN protection",
                "All Basic features"
            ],
            badge: "POPULAR"
        ),
        PlanCard(
            id: "max",
            name: "Max",
            monthlyTokens: 250,
            monthlyPrice: 29,
            yearlyPrice: 290,
            color: AppColors.primaryPink,
            icon: "crown.fill",
            features: [
                "250 credits every month",
                "1K/2K quality selector",
                "Commercial license",
                "All Pro features"
            ]
        ),
        PlanCard(
            id: "business",
            name: "Business",
            monthlyTokens: 1000,
            monthlyPrice: 99,
            yearlyPrice: 990,
            color: AppColors.primaryTeal, // Cyan Teal - Professional and modern
            icon: "briefcase.fill",
            features: [
                "1000 credits every month",
                "Multiple AI models",
                "Priority support",
                "All Max features"
            ],
            badge: "ENTERPRISE"
        )
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Yearly/Monthly toggle
                billingToggle
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.md)

                // Swipeable plan cards
                TabView(selection: $currentPlanIndex) {
                    ForEach(plans.indices, id: \.self) { index in
                        CompactPlanCard(
                            plan: plans[index],
                            isYearly: isYearly
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)

                // Page indicator dots
                HStack(spacing: 8) {
                    ForEach(plans.indices, id: \.self) { index in
                        Circle()
                            .fill(currentPlanIndex == index ? currentPlan.color : AppColors.borderLight)
                            .frame(width: currentPlanIndex == index ? 10 : 8, height: currentPlanIndex == index ? 10 : 8)
                            .animation(.spring(response: 0.3), value: currentPlanIndex)
                    }
                }
                .padding(.vertical, AppSpacing.sm)

                // Fixed bottom CTA
                fixedBottomCTA
            }
            .background(
                LinearGradient(
                    colors: [
                        AppColors.backgroundLight,
                        currentPlan.color.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Unlock Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Components

    private var currentPlan: PlanCard {
        plans[currentPlanIndex]
    }

    private var compactHeader: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 24))
                .foregroundColor(currentPlan.color)
                .symbolEffect(.bounce, value: currentPlanIndex)

            Text("Unlock Premium")
                .font(AppTypography.headlineMedium)
                .foregroundColor(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    private var billingToggle: some View {
        HStack(spacing: 0) {
            // Monthly button
            Button(action: { withAnimation(.spring(response: 0.3)) { isYearly = false } }) {
                Text("Monthly")
                    .font(AppTypography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(isYearly ? AppColors.textSecondary : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm)
                    .background(isYearly ? Color.clear : currentPlan.color)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Yearly button with savings badge
            Button(action: { withAnimation(.spring(response: 0.3)) { isYearly = true } }) {
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Yearly")
                            .font(AppTypography.bodyMedium)
                            .fontWeight(.semibold)

                        Text("SAVE 17%")
                            .font(AppTypography.captionSmall)
                            .fontWeight(.bold)
                            .foregroundColor(isYearly ? currentPlan.color : AppColors.successGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(isYearly ? .white : AppColors.successGreen.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                .foregroundColor(isYearly ? .white : AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
                .background(isYearly ? currentPlan.color : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(4)
        .background(AppColors.surfaceLight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.borderLight, lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.xl)
    }

    private var fixedBottomCTA: some View {
        VStack(spacing: AppSpacing.sm) {
            // Price per day callout
            HStack(spacing: 4) {
                Text("Just")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(AppColors.textSecondary)

                Text(pricePerDay)
                    .font(AppTypography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(currentPlan.color)

                Text("per day • Cancel anytime")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(AppColors.textSecondary)
            }

            // Subscribe button
            Button(action: { selectPlan(currentPlan) }) {
                HStack(spacing: AppSpacing.sm) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Start Free Trial")
                            .font(AppTypography.buttonLarge)
                            .fontWeight(.bold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    LinearGradient(
                        colors: [currentPlan.color, currentPlan.color.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: currentPlan.color.opacity(0.4), radius: 12, x: 0, y: 6)
            }
            .disabled(isLoading)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
        }
        .padding(.top, AppSpacing.sm)
        .background(.ultraThinMaterial)
    }

    private var pricePerDay: String {
        let price = isYearly ? currentPlan.yearlyPrice : currentPlan.monthlyPrice
        let days = isYearly ? 365 : 30
        let perDay = Double(price) / Double(days)
        return String(format: "$%.2f", perDay)
    }

    // MARK: - Actions

    private func selectPlan(_ plan: PlanCard) {
        print("🎯 SubscriptionPlans: Selected \(plan.name) - \(isYearly ? "Yearly" : "Monthly")")
        // TODO: Implement Stripe checkout
        isLoading = true

        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isLoading = false
            errorMessage = "Stripe integration coming soon!"
            showingError = true
        }
    }
}

// MARK: - Plan Card Data Model

struct PlanCard: Identifiable {
    let id: String
    let name: String
    let monthlyTokens: Int
    let monthlyPrice: Int
    let yearlyPrice: Int
    let color: Color
    let icon: String
    let features: [String]
    let badge: String?

    init(id: String, name: String, monthlyTokens: Int, monthlyPrice: Int, yearlyPrice: Int, color: Color, icon: String, features: [String], badge: String? = nil) {
        self.id = id
        self.name = name
        self.monthlyTokens = monthlyTokens
        self.monthlyPrice = monthlyPrice
        self.yearlyPrice = yearlyPrice
        self.color = color
        self.icon = icon
        self.features = features
        self.badge = badge
    }
}

// MARK: - Compact Plan Card

struct CompactPlanCard: View {
    let plan: PlanCard
    let isYearly: Bool

    private var price: Int {
        isYearly ? plan.yearlyPrice : plan.monthlyPrice
    }

    private var priceText: String {
        "$\(price)"
    }

    private var periodText: String {
        isYearly ? "/year" : "/mo"
    }

    private var savingsText: String? {
        guard isYearly else { return nil }
        let monthlyTotal = plan.monthlyPrice * 12
        let savings = monthlyTotal - plan.yearlyPrice
        return "Save $\(savings)"
    }

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Top: Logo image with badge
            ZStack(alignment: .topTrailing) {
                // Centered logo
                Image("sketchwink-logo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(plan.color.opacity(0.3), lineWidth: 3)
                    )
                    .shadow(color: plan.color.opacity(0.2), radius: 8, x: 0, y: 4)
                    .frame(maxWidth: .infinity)

                if let badge = plan.badge {
                    Text(badge)
                        .font(AppTypography.captionSmall)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppColors.successGreen)
                        .clipShape(Capsule())
                        .offset(x: -8, y: 0)
                }
            }

            // Middle: Plan name and price
            VStack(spacing: 4) {
                Text(plan.name)
                    .font(AppTypography.headlineMedium)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(priceText)
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundColor(plan.color)

                    Text(periodText)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                }

                if let savings = savingsText {
                    Text(savings)
                        .font(AppTypography.captionLarge)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.successGreen)
                }
            }

            // Credits badge
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(plan.color)

                Text("\(plan.monthlyTokens) credits/month")
                    .font(AppTypography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .background(plan.color.opacity(0.1))
            .clipShape(Capsule())

            // Features list
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                ForEach(plan.features, id: \.self) { feature in
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(plan.color)

                        Text(feature)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.lg)
        .background(AppColors.surfaceLight)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(plan.color.opacity(0.3), lineWidth: 2)
        )
        .shadow(
            color: plan.color.opacity(0.15),
            radius: 16,
            x: 0,
            y: 8
        )
        .padding(.horizontal, AppSpacing.lg)
    }
}

// MARK: - Preview

#Preview {
    SubscriptionPlansView()
}
