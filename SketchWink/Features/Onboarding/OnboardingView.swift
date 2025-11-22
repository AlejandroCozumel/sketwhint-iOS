import SwiftUI

struct OnboardingHighlight: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
}

struct OnboardingSlide: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let emoji: String
    let gradientColors: [Color]
    let accentColor: Color
    let highlights: [OnboardingHighlight]
}

struct OnboardingView: View {
    @State private var currentIndex = 0
    private let slides: [OnboardingSlide]
    private let onFinish: () -> Void

    init(
        slides: [OnboardingSlide] = OnboardingView.defaultSlides,
        onFinish: @escaping () -> Void
    ) {
        self.slides = slides
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            // Background Layer
            ZStack {
                ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                    if index == currentIndex {
                        LinearGradient(
                            colors: slide.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea()
                        .transition(.opacity.animation(.easeInOut(duration: 0.5)))
                        .zIndex(Double(index))
                    }
                }
            }

            // Decorative Background Shapes
            GeometryReader { proxy in
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 300, height: 300)
                        .offset(x: -100, y: -100)
                        .blur(radius: 20)
                    
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 200, height: 200)
                        .offset(x: proxy.size.width - 100, y: 100)
                        .blur(radius: 10)
                    
                    StarShape()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 150, height: 150)
                        .offset(x: proxy.size.width - 50, y: -50)
                        .rotationEffect(.degrees(Double(currentIndex) * 45))
                        .animation(.spring(response: 0.8, dampingFraction: 0.6), value: currentIndex)
                }
            }
            .ignoresSafeArea()

            // Content Layer
            VStack(spacing: 0) {
                Spacer()
                
                // Hero Emoji/Image Area
                ZStack {
                    ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                        if index == currentIndex {
                            Text(slide.emoji)
                                .font(.system(size: 120))
                                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                                .scaleEffect(currentIndex == index ? 1.0 : 0.8)
                                .transition(.scale.combined(with: .opacity))
                                .id("emoji-\(index)")
                        }
                    }
                }
                .frame(height: 300)
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: currentIndex)

                // Bottom Card
                VStack(spacing: AppSpacing.xl) {
                    // Indicators
                    HStack(spacing: 8) {
                        ForEach(0..<slides.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentIndex ? slides[currentIndex].accentColor : AppColors.borderLight)
                                .frame(width: index == currentIndex ? 24 : 8, height: 8)
                                .animation(.spring(), value: currentIndex)
                        }
                    }
                    .padding(.top, AppSpacing.lg)

                    // Text Content
                    VStack(spacing: AppSpacing.md) {
                        Text(slides[currentIndex].title)
                            .font(AppTypography.onboardingTitle)
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.9)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, AppSpacing.lg)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                            .id("title-\(currentIndex)")

                        Text(slides[currentIndex].message)
                            .font(AppTypography.bodyMedium)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.md)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                            .id("message-\(currentIndex)")
                    }
                    .animation(.easeInOut(duration: 0.3), value: currentIndex)

                    // Highlights Badges (Vertical Stack)
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(slides[currentIndex].highlights) { highlight in
                            HStack(spacing: 12) {
                                Image(systemName: highlight.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(slides[currentIndex].accentColor)
                                    .frame(width: 24)

                                Text(highlight.text)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textPrimary)

                                Spacer()
                            }
                            .padding(.horizontal, AppSpacing.lg)
                            .padding(.vertical, AppSpacing.md)
                            .background(slides[currentIndex].accentColor.opacity(0.1))
                            .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                    .id("highlights-\(currentIndex)")
                    .animation(.easeInOut(duration: 0.3), value: currentIndex)

                    Spacer()

                    // Action Buttons
                    VStack(spacing: AppSpacing.md) {
                        Button(action: advance) {
                            Text(currentIndex == slides.count - 1 ? "onboarding.button.get.started".localized : "onboarding.button.next".localized)
                                .font(AppTypography.buttonText)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(slides[currentIndex].accentColor)
                                .cornerRadius(28)
                                .shadow(color: slides[currentIndex].accentColor.opacity(0.4), radius: 10, x: 0, y: 5)
                        }

                        if currentIndex < slides.count - 1 {
                            Button(action: finish) {
                                Text("onboarding.button.skip".localized)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        } else {
                            Text("")
                                .font(AppTypography.bodyMedium)
                                .hidden()
                                .frame(height: 20) // Maintain spacing
                        }
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.bottom, AppSpacing.xl)
                }
                .background(Color.white)
                .cornerRadius(32, corners: [.topLeft, .topRight])
                .shadow(color: Color.black.opacity(0.1), radius: 30, x: 0, y: -10)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width < -50 {
                        advance()
                    } else if value.translation.width > 50 {
                        back()
                    }
                }
        )
    }

    private func advance() {
        withAnimation {
            if currentIndex < slides.count - 1 {
                currentIndex += 1
            } else {
                finish()
            }
        }
    }
    
    private func back() {
        withAnimation {
            if currentIndex > 0 {
                currentIndex -= 1
            }
        }
    }

    private func finish() {
        onFinish()
    }
}

// MARK: - Decorative Shapes
struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let pointsOnStar = 5
        var path = Path()
        
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * 0.4
        
        var angle = -CGFloat.pi / 2
        let angleIncrement = CGFloat.pi * 2 / CGFloat(pointsOnStar * 2)
        
        for i in 0..<pointsOnStar * 2 {
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
            
            angle += angleIncrement
        }
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Data
private extension OnboardingView {
    static var defaultSlides: [OnboardingSlide] {
        [
            OnboardingSlide(
                title: String(localized: "onboarding.welcome.title"),
                message: String(localized: "onboarding.welcome.message"),
                emoji: "✨",
                gradientColors: [AppColors.primaryIndigo, AppColors.primaryBlue],
                accentColor: AppColors.primaryIndigo,
                highlights: [
                    OnboardingHighlight(icon: "sparkles", text: String(localized: "onboarding.welcome.highlight1")),
                    OnboardingHighlight(icon: "hand.thumbsup.fill", text: String(localized: "onboarding.welcome.highlight2"))
                ]
            ),
            OnboardingSlide(
                title: String(localized: "onboarding.create.title"),
                message: String(localized: "onboarding.create.message"),
                emoji: "🎨",
                gradientColors: [AppColors.primaryTeal, AppColors.primaryIndigo],
                accentColor: AppColors.primaryTeal,
                highlights: [
                    OnboardingHighlight(icon: "paintpalette.fill", text: String(localized: "onboarding.create.highlight1")),
                    OnboardingHighlight(icon: "clock.badge.checkmark", text: String(localized: "onboarding.create.highlight2"))
                ]
            ),
            OnboardingSlide(
                title: String(localized: "onboarding.stories.title"),
                message: String(localized: "onboarding.stories.message"),
                emoji: "🌙",
                gradientColors: [AppColors.primaryPink, AppColors.primaryTeal],
                accentColor: AppColors.primaryPink,
                highlights: [
                    OnboardingHighlight(icon: "book.fill", text: String(localized: "onboarding.stories.highlight1")),
                    OnboardingHighlight(icon: "person.2.wave.2.fill", text: String(localized: "onboarding.stories.highlight2"))
                ]
            )
        ]
    }
}

#Preview {
    OnboardingView(onFinish: {})
}

