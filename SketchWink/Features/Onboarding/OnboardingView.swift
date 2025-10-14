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
    let backgroundColor: Color
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
        ZStack(alignment: .top) {
            TabView(selection: $currentIndex) {
                ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                    OnboardingSlideView(
                        slide: slide,
                        index: index,
                        currentIndex: currentIndex,
                        totalSlides: slides.count,
                        onAdvance: advance,
                        onFinish: finish
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.4), value: currentIndex)

            header
        }
        .ignoresSafeArea()
    }

    private var header: some View { EmptyView() }

    private func advance() {
        if currentIndex < slides.count - 1 {
            currentIndex += 1
        } else {
            finish()
        }
    }

    private func finish() {
        DispatchQueue.main.async {
            onFinish()
        }
    }
}

private struct OnboardingSlideView: View {
    let slide: OnboardingSlide
    let index: Int
    let currentIndex: Int
    let totalSlides: Int
    let onAdvance: () -> Void
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: AppSpacing.sectionSpacing)

            VStack(spacing: AppSpacing.xl) {
                VStack(spacing: AppSpacing.md) {
                    Text(slide.emoji)
                        .font(.system(size: AppSizing.iconSizes.xxl))
                        .shadow(radius: 12)

                    Text(slide.title)
                        .onboardingTitle()
                        .foregroundColor(AppColors.textOnColor)
                        .multilineTextAlignment(.center)

                    Text(slide.message)
                        .onboardingBody()
                        .foregroundColor(AppColors.textOnColor.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineSpacing(AppSpacing.lineSpacing)
                        .padding(.horizontal, AppSpacing.md)
                }

                VStack(spacing: AppSpacing.sm) {
                    ForEach(slide.highlights) { highlight in
                        OnboardingHighlightChip(highlight: highlight, accentColor: slide.accentColor)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.pageMargin)

            Spacer(minLength: AppSpacing.sectionSpacing)

            VStack(spacing: AppSpacing.xs) {
                pageIndicators
                primaryButton
                skipForNowButton
            }
            .padding(.horizontal, AppSpacing.pageMargin)
            .padding(.bottom, AppSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BackgroundView())
        .edgesIgnoringSafeArea(.all)
    }
}

private struct BackgroundView: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle()
                    .fill(AppColors.primaryBlue)
                    .ignoresSafeArea()

                Circle()
                    .fill(AppColors.surfaceLight.opacity(0.12))
                    .frame(width: proxy.size.width * 1.3)
                    .offset(x: -proxy.size.width * 0.4, y: -proxy.size.height * 0.35)

                Circle()
                    .fill(AppColors.surfaceLight.opacity(0.08))
                    .frame(width: proxy.size.width)
                    .offset(x: proxy.size.width * 0.35, y: -proxy.size.height * 0.2)
            }
        }
    }
}

private extension OnboardingSlideView {
    var isCurrent: Bool { index == currentIndex }

    var buttonTitle: String { currentIndex == totalSlides - 1 ? "Get Started" : "Next" }

    var buttonIcon: String { currentIndex == totalSlides - 1 ? "checkmark.circle.fill" : "arrow.right.circle.fill" }

    var pageIndicators: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(0..<totalSlides, id: \.self) { indicatorIndex in
                Capsule()
                    .fill(indicatorIndex == currentIndex ? Color.white : Color.white.opacity(0.35))
                    .frame(width: indicatorIndex == currentIndex ? 36 : 12, height: 8)
                    .animation(.easeInOut(duration: 0.3), value: currentIndex)
            }
        }
        .accessibilityIdentifier("onboarding-page-indicators")
    }

    var primaryButton: some View {
        Button(action: {
            if currentIndex == totalSlides - 1 {
                onFinish()
            } else {
                onAdvance()
            }
        }) {
            HStack(spacing: AppSpacing.sm) {
                Text(buttonTitle)
                Image(systemName: buttonIcon)
                    .font(.system(size: AppSizing.iconSizes.lg, weight: .semibold))
            }
            .largeButtonStyle(
                backgroundColor: AppColors.surfaceLight,
                foregroundColor: AppColors.primaryBlue
            )
        }
        .accessibilityIdentifier("onboarding-primary-button")
        .opacity(isCurrent ? 1 : 0)
        .disabled(!isCurrent)
    }

    var skipForNowButton: some View {
        Button(action: {
            onFinish()
        }) {
            Text("Skip")
                .buttonText()
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xs)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("onboarding-skip-for-now")
        .opacity(isCurrent ? 1 : 0)
        .disabled(!isCurrent)
    }
}

private struct OnboardingHighlightChip: View {
    let highlight: OnboardingHighlight
    let accentColor: Color

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: highlight.icon)
                .foregroundColor(accentColor)
                .font(.system(size: AppSizing.iconSizes.md, weight: .semibold))
                .frame(width: AppSizing.iconSizes.lg, height: AppSizing.iconSizes.lg)

            Text(highlight.text)
                .onboardingBody()
                .foregroundColor(AppColors.textOnColor)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, AppSpacing.pageMargin)
        .padding(.vertical, AppSpacing.sm)
        .background(
            Capsule()
                .fill(AppColors.textOnColor.opacity(0.12))
        )
        .clipShape(Capsule())
    }
}

private extension OnboardingView {
    static var defaultSlides: [OnboardingSlide] {
        [
            OnboardingSlide(
                title: "Welcome to SketchWink",
                message: "Start your creative journey with 3 free credits. Experiment with art styles and see what the AI can do without any commitment.",
                emoji: "✨",
                backgroundColor: AppColors.primaryBlue,
                accentColor: AppColors.primaryPurple,
                highlights: [
                    OnboardingHighlight(icon: "sparkles", text: "3 credits ready to use"),
                    OnboardingHighlight(icon: "hand.thumbsup.fill", text: "No card required to explore")
                ]
            ),
            OnboardingSlide(
                title: "Create Magical Art",
                message: "Turn ideas into coloring pages, stickers, and more. Customize prompts, pick palettes, and bring family projects to life in seconds.",
                emoji: "🎨",
                backgroundColor: AppColors.primaryPurple,
                accentColor: AppColors.primaryPink,
                highlights: [
                    OnboardingHighlight(icon: "paintpalette.fill", text: "Kid-friendly art tools"),
                    OnboardingHighlight(icon: "clock.badge.checkmark", text: "Lightning-fast generations")
                ]
            ),
            OnboardingSlide(
                title: "Stories & Family Profiles",
                message: "Unlock bedtime stories, shared galleries, and PIN-protected profiles with a SketchWink plan. Perfect for families who create together.",
                emoji: "🌙",
                backgroundColor: AppColors.primaryIndigo,
                accentColor: AppColors.primaryTeal,
                highlights: [
                    OnboardingHighlight(icon: "book.fill", text: "Bedtime stories on tap"),
                    OnboardingHighlight(icon: "person.2.wave.2.fill", text: "Family profiles for premium members")
                ]
            )
        ]
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
