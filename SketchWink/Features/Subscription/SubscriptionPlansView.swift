import SwiftUI

struct SubscriptionPlansView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tokenManager = TokenBalanceManager.shared
    @StateObject private var viewModel = SubscriptionViewModel()

    @State private var currentPlanIndex = 1 // Start at Basic plan
    @State private var isYearly = true // Default to yearly for better value

    // Plan data - from backend seed database
    private let plans = [
        PlanCard(
            id: "basic",
            name: "Basic",
            monthlyTokens: 50,
            monthlyPrice: 999,
            yearlyPrice: 9999,
            color: AppColors.primaryBlue,
            icon: "paintbrush.fill",
            features: [
                "50 credits every month",
                "All art styles",
                "Up to 5 family profiles",
                "3-month credit rollover (150 tokens)"
            ]
        ),
        PlanCard(
            id: "pro",
            name: "Pro",
            monthlyTokens: 120,
            monthlyPrice: 1999,
            yearlyPrice: 19999,
            color: AppColors.primaryPurple,
            icon: "star.fill",
            features: [
                "120 credits every month",
                "PIN profile protection",
                "Token rollover up to 360 credits",
                "All features from Basic"
            ],
            badge: "POPULAR"
        ),
        PlanCard(
            id: "max",
            name: "Max",
            monthlyTokens: 250,
            monthlyPrice: 2999,
            yearlyPrice: 29999,
            color: AppColors.primaryPink,
            icon: "crown.fill",
            features: [
                "250 credits every month",
                "1K/2K image quality",
                "Commercial license",
                "All features from Pro"
            ]
        ),
        PlanCard(
            id: "business",
            name: "Business",
            monthlyTokens: 1000,
            monthlyPrice: 9999,
            yearlyPrice: 99999,
            color: AppColors.primaryTeal, // Cyan Teal - Professional and modern
            icon: "briefcase.fill",
            features: [
                "1000 credits every month",
                "Switch between AI models",
                "Priority support",
                "All features from Max"
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppColors.textSecondary)
                            .padding(8)
                            .background(AppColors.surfaceLight)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(AppColors.borderLight, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
            }
            .toolbarBackground(AppColors.backgroundLight, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
                ZStack {
                    // Invisible placeholder to define height
                    VStack(spacing: 2) {
                        Text("Yearly")
                            .font(AppTypography.bodyLarge)
                            .fontWeight(.semibold)
                            .opacity(0)

                        Text("SAVE 2 MONTHS")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .opacity(0)
                    }

                    Text("Monthly")
                        .font(AppTypography.bodyLarge)
                        .fontWeight(.semibold)
                }
                .foregroundColor(isYearly ? AppColors.textSecondary : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
                .background(isYearly ? Color.clear : currentPlan.color)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            // Yearly button with savings badge
            Button(action: { withAnimation(.spring(response: 0.3)) { isYearly = true } }) {
                VStack(spacing: 2) {
                    Text("Yearly")
                        .font(AppTypography.bodyLarge)
                        .fontWeight(.semibold)

                    Text("SAVE 2 MONTHS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isYearly ? currentPlan.color : AppColors.successGreen)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isYearly ? .white : AppColors.successGreen.opacity(0.15))
                        .clipShape(Capsule())
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
            Button(action: {
                viewModel.purchase(plan: currentPlan, isYearly: isYearly)
            }) {
                HStack(spacing: AppSpacing.sm) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Subscribe Now")
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
            .disabled(viewModel.isLoading)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)
        }
        .padding(.top, AppSpacing.sm)
        .background(.ultraThinMaterial)
        .alert("Notice", isPresented: $viewModel.showingError) {
            Button("OK") {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    private var pricePerDay: String {
        let price = isYearly ? currentPlan.yearlyPrice : currentPlan.monthlyPrice
        let days = isYearly ? 365 : 30
        let perDay = (Double(price) / 100.0) / Double(days)
        return String(format: "$%.2f", perDay)
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



    private var periodText: String {
        isYearly ? "/year" : "/mo"
    }

    private var savingsText: String? {
        guard isYearly else { return nil }
        let monthlyTotal = plan.monthlyPrice * 12
        let savings = monthlyTotal - plan.yearlyPrice
        let savingsInDollars = Double(savings) / 100.0
        return String(format: "Save $%.2f", savingsInDollars)
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
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("$")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundColor(plan.color)
                            .padding(.trailing, 4)
                        Text("\(price / 100)")
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .foregroundColor(plan.color)
                        Text(String(format: ".%02d", price % 100))
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(plan.color)
                            .baselineOffset(12)
                    }

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
