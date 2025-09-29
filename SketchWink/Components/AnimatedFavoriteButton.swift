import SwiftUI

/// Animated favorite button with Twitter-style heart animation and sparkle effects
/// Used throughout the app for consistent favorite interactions
struct AnimatedFavoriteButton: View {
    let isFavorite: Bool
    let onToggle: () -> Void
    
    @State private var isLiked = false
    @State private var sparkleOpacity: Double = 0
    @State private var sparkleScale: CGFloat = 0
    @State private var heartScale: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Twitter-style animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                heartScale = 0.8
            }
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.4).delay(0.1)) {
                heartScale = 1.2
                sparkleScale = 1.0
                sparkleOpacity = 1.0
            }
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.2)) {
                heartScale = 1.0
            }
            
            // Sparkles fade out
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                sparkleOpacity = 0
                sparkleScale = 1.5
            }
            
            // Reset sparkles
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                sparkleScale = 0
            }
            
            // Toggle state and call action
            isLiked.toggle()
            onToggle()
        }) {
            ZStack {
                // Main background circle
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                    .shadow(
                        color: isFavorite ? Color.pink.opacity(0.3) : Color.black.opacity(0.1),
                        radius: isFavorite ? 6 : 2,
                        x: 0,
                        y: 2
                    )
                
                // Sparkle Effect - Small yellow circles radiating outward
                ForEach(0..<8, id: \.self) { index in
                    Sparkle(index: index)
                        .opacity(sparkleOpacity)
                        .scaleEffect(sparkleScale)
                }
                
                // Heart icon with Twitter-style animation
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(
                        isFavorite ?
                        LinearGradient(
                            colors: [.pink, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(heartScale)
            }
        }
        .childSafeTouchTarget()
        .onAppear {
            isLiked = isFavorite
        }
        .onChange(of: isFavorite) {
            isLiked = isFavorite
        }
    }
}

// MARK: - Sparkle Component
struct Sparkle: View {
    let index: Int
    
    var body: some View {
        Circle()
            .fill(Color.yellow)
            .frame(width: 4, height: 4)
            .offset(sparkleOffset)
    }
    
    private var sparkleOffset: CGSize {
        // Calculate random offset in different directions
        let angle = Double(index) * (360.0 / 8.0) * .pi / 180.0
        let distance: CGFloat = CGFloat.random(in: 25...35)
        let randomX = cos(angle) * distance + CGFloat.random(in: -8...8)
        let randomY = sin(angle) * distance + CGFloat.random(in: -8...8)
        return CGSize(width: randomX, height: randomY)
    }
}

#Preview {
    VStack(spacing: 20) {
        AnimatedFavoriteButton(isFavorite: false) {
            print("Favorite toggled")
        }
        
        AnimatedFavoriteButton(isFavorite: true) {
            print("Favorite toggled")
        }
    }
    .padding()
    .background(AppColors.backgroundLight)
}