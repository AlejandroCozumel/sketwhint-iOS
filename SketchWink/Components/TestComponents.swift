import SwiftUI

// MARK: - Test Components for ContentView

struct CategoryTestCard: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Text(icon)
                .font(.system(size: AppSizing.iconSizes.xl))
            
            Text(title)
                .categoryTitle()
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(color)
        .cornerRadius(AppSizing.cornerRadius.md)
        .childSafeTouchTarget()
        .shadow(
            color: Color.black.opacity(AppSizing.shadows.small.opacity),
            radius: AppSizing.shadows.small.radius,
            x: AppSizing.shadows.small.x,
            y: AppSizing.shadows.small.y
        )
    }
}

struct ColorCircle: View {
    let color: Color
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 24, height: 24)
            .overlay(
                Circle()
                    .stroke(AppColors.borderLight, lineWidth: AppSizing.borderWidth.thin)
            )
    }
}

// MARK: - Preview Provider
#if DEBUG
struct TestComponentsPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Category Cards
                LazyVGrid(columns: GridLayouts.categoryGrid, spacing: AppSpacing.grid.rowSpacing) {
                    CategoryTestCard(
                        title: "Coloring Pages",
                        icon: "🎨",
                        color: AppColors.coloringPagesColor
                    )
                    
                    CategoryTestCard(
                        title: "Stickers",
                        icon: "✨",
                        color: AppColors.stickersColor
                    )
                }
                
                // Color Circles
                HStack(spacing: AppSpacing.sm) {
                    ColorCircle(color: AppColors.primaryBlue)
                    ColorCircle(color: AppColors.primaryPurple)
                    ColorCircle(color: AppColors.primaryPink)
                    ColorCircle(color: AppColors.buttercup)
                    ColorCircle(color: AppColors.limeGreen)
                }
            }
            .pageMargins()
        }
        .background(AppColors.backgroundLight)
    }
}

#Preview {
    TestComponentsPreview()
}
#endif