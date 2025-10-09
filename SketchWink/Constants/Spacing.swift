import SwiftUI

/// Spacing and layout constants for SketchWink
/// Designed for child-friendly interfaces with larger touch targets and clear visual hierarchy
struct AppSpacing {
    
    // MARK: - Base Spacing Units (in points)
    static let xxxs: CGFloat = 2    // Micro spacing
    static let xxs: CGFloat = 4     // Very small spacing
    static let xs: CGFloat = 8      // Extra small spacing
    static let sm: CGFloat = 12     // Small spacing
    static let md: CGFloat = 16     // Medium spacing (base unit)
    static let lg: CGFloat = 24     // Large spacing
    static let xl: CGFloat = 32     // Extra large spacing
    static let xxl: CGFloat = 48    // Very large spacing
    static let xxxl: CGFloat = 64   // Maximum spacing
    
    // MARK: - Semantic Spacing
    
    /// Spacing between UI elements on the same level
    static let elementSpacing = md
    
    /// Spacing between sections
    static let sectionSpacing = lg
    
    /// Spacing between major sections or screens
    static let majorSectionSpacing = xl
    
    /// Page margins and safe area padding
    static let pageMargin = md
    
    /// Content padding inside cards or containers
    static let contentPadding = md
    
    /// Spacing between text lines for better readability
    static let lineSpacing: CGFloat = 4
    
    /// Spacing between paragraphs
    static let paragraphSpacing = sm
    
    // MARK: - Component-Specific Spacing
    
    /// Spacing inside buttons
    static let buttonPadding = ButtonPadding()
    struct ButtonPadding {
        let horizontal: CGFloat = 20
        let vertical: CGFloat = 12
        let large = ButtonPaddingLarge()
        
        struct ButtonPaddingLarge {
            let horizontal: CGFloat = 24
            let vertical: CGFloat = 16
        }
    }
    
    /// Spacing for cards and containers
    static let cardPadding = CardPadding()
    struct CardPadding {
        let inner: CGFloat = md          // Inside card content
        let outer: CGFloat = sm          // Between cards
        let section: CGFloat = lg        // Between card sections
    }
    
    /// Spacing for navigation elements
    static let navigation = NavigationSpacing()
    struct NavigationSpacing {
        let itemSpacing: CGFloat = lg    // Between nav items
        let iconToText: CGFloat = xs     // Icon to text spacing
        let titlePadding: CGFloat = md   // Navigation title padding
    }
    
    /// Spacing for form elements
    static let form = FormSpacing()
    struct FormSpacing {
        let fieldSpacing: CGFloat = md   // Between form fields
        let labelToField: CGFloat = xs   // Label to input spacing
        let fieldPadding: CGFloat = sm   // Inside input fields
        let groupSpacing: CGFloat = lg   // Between form groups
    }
    
    /// Spacing for grid layouts
    static let grid = GridSpacing()
    struct GridSpacing {
        let itemSpacing: CGFloat = sm    // Between grid items
        let rowSpacing: CGFloat = md     // Between grid rows
        let sectionSpacing: CGFloat = lg // Between grid sections
    }
    
    /// Spacing for lists
    static let list = ListSpacing()
    struct ListSpacing {
        let itemSpacing: CGFloat = xs    // Between list items
        let sectionSpacing: CGFloat = md // Between list sections
        let itemPadding: CGFloat = md    // Inside list items
    }
}

/// Layout dimensions and sizing constants
struct AppSizing {
    
    // MARK: - Touch Targets (optimized for children)
    static let minTouchTarget: CGFloat = 44     // Minimum touch target size
    static let recommendedTouchTarget: CGFloat = 56  // Recommended for children
    static let largeTouchTarget: CGFloat = 64   // Large touch target for primary actions
    
    // MARK: - Component Heights
    static let textFieldHeight: CGFloat = 50    // Text input fields
    static let buttonHeight: CGFloat = 48       // Standard buttons
    static let largeButtonHeight: CGFloat = 56  // Primary action buttons
    static let toolbarHeight: CGFloat = 56      // Custom toolbar height
    static let tabBarHeight: CGFloat = 83       // Tab bar height (including safe area)
    
    // MARK: - Component Widths
    static let maxContentWidth: CGFloat = 600   // Maximum content width for larger screens
    static let minContentWidth: CGFloat = 280   // Minimum content width
    static let sidebarWidth: CGFloat = 320      // Sidebar width on iPad
    
    // MARK: - Icon Sizes
    static let iconSizes = IconSizes()
    struct IconSizes {
        let xs: CGFloat = 12        // Very small icons
        let sm: CGFloat = 16        // Small icons (in text)
        let md: CGFloat = 24        // Medium icons (buttons)
        let lg: CGFloat = 32        // Large icons (navigation)
        let xl: CGFloat = 48        // Extra large icons (categories)
        let xxl: CGFloat = 64       // Very large icons (onboarding)
    }
    
    // MARK: - Image Sizes
    static let imageSizes = ImageSizes()
    struct ImageSizes {
        let thumbnail: CGFloat = 80      // Small thumbnails
        let card: CGFloat = 120         // Card images
        let preview: CGFloat = 200      // Preview images
        let hero: CGFloat = 300         // Hero images
        let avatar: CGFloat = 40        // Profile avatars
        let avatarLarge: CGFloat = 80   // Large profile avatars
    }
    
    // MARK: - Corner Radius
    static let cornerRadius = CornerRadius()
    struct CornerRadius {
        let xs: CGFloat = 4         // Very small radius
        let sm: CGFloat = 8         // Small radius
        let md: CGFloat = 12        // Medium radius (default)
        let lg: CGFloat = 16        // Large radius
        let xl: CGFloat = 20        // Extra large radius
        let round: CGFloat = 1000   // Fully rounded (for pills/capsule)
    }
    
    // MARK: - Border Widths
    static let borderWidth = BorderWidth()
    struct BorderWidth {
        let thin: CGFloat = 0.5     // Hairline borders
        let regular: CGFloat = 1    // Regular borders
        let thick: CGFloat = 2      // Thick borders
        let heavy: CGFloat = 4      // Heavy borders (focus states)
    }
    
    // MARK: - Shadow Properties
    static let shadows = ShadowProperties()
    struct ShadowProperties {
        let small = ShadowSmall()
        let medium = ShadowMedium()
        let large = ShadowLarge()
        
        struct ShadowSmall {
            let radius: CGFloat = 2
            let x: CGFloat = 0
            let y: CGFloat = 1
            let opacity: Double = 0.1
        }
        
        struct ShadowMedium {
            let radius: CGFloat = 8
            let x: CGFloat = 0
            let y: CGFloat = 4
            let opacity: Double = 0.15
        }
        
        struct ShadowLarge {
            let radius: CGFloat = 16
            let x: CGFloat = 0
            let y: CGFloat = 8
            let opacity: Double = 0.2
        }
    }
}

/// Layout helpers and modifiers
struct LayoutHelpers {
    
    /// Returns appropriate spacing based on device size
    static func adaptiveSpacing(compact: CGFloat, regular: CGFloat) -> CGFloat {
        // This can be enhanced with actual size class detection
        return regular
    }
    
    /// Returns appropriate sizing based on device
    static func adaptiveSize(phone: CGFloat, pad: CGFloat) -> CGFloat {
        // This can be enhanced with actual device detection
        return phone
    }
}

// MARK: - View Modifiers for Consistent Spacing
extension View {
    
    /// Apply standard content padding
    func contentPadding() -> some View {
        self.padding(AppSpacing.contentPadding)
    }
    
    /// Apply page margins
    func pageMargins() -> some View {
        self.padding(.horizontal, AppSpacing.pageMargin)
    }
    
    /// Apply section spacing
    func sectionSpacing() -> some View {
        self.padding(.vertical, AppSpacing.sectionSpacing)
    }
    
    /// Apply card styling with padding and background
    func cardStyle() -> some View {
        self
            .padding(AppSpacing.cardPadding.inner)
            .background(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                    .fill(AppColors.surfaceLight)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md)
                            .stroke(AppColors.primaryBlue.opacity(0.1), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: AppSizing.cornerRadius.md))
            .shadow(
                color: AppColors.primaryBlue.opacity(0.06),
                radius: 6,
                x: 0,
                y: 3
            )
    }
    
    /// Apply button styling
    func buttonStyle(
        backgroundColor: Color = AppColors.primaryBlue,
        foregroundColor: Color = .white,
        cornerRadius: CGFloat = AppSizing.cornerRadius.md
    ) -> some View {
        self
            .padding(.horizontal, AppSpacing.buttonPadding.horizontal)
            .padding(.vertical, AppSpacing.buttonPadding.vertical)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(cornerRadius)
    }
    
    /// Apply large button styling for primary actions
    func largeButtonStyle(
        backgroundColor: Color = AppColors.primaryBlue,
        foregroundColor: Color = .white
    ) -> some View {
        self
            .font(AppTypography.titleMedium)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.buttonPadding.large.horizontal)
            .padding(.vertical, AppSpacing.buttonPadding.large.vertical)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .clipShape(Capsule())
            .shadow(
                color: Color.black.opacity(AppSizing.shadows.medium.opacity),
                radius: AppSizing.shadows.medium.radius,
                x: AppSizing.shadows.medium.x,
                y: AppSizing.shadows.medium.y
            )
    }
    
    /// Apply form field styling
    func formFieldStyle() -> some View {
        self
            .padding(AppSpacing.form.fieldPadding)
            .frame(height: AppSizing.textFieldHeight)
            .background(AppColors.surfaceLight)
            .cornerRadius(AppSizing.cornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                    .stroke(AppColors.borderLight, lineWidth: AppSizing.borderWidth.regular)
            )
    }
    
    /// Apply child-safe touch target sizing
    func childSafeTouchTarget() -> some View {
        self
            .frame(minWidth: AppSizing.recommendedTouchTarget, minHeight: AppSizing.recommendedTouchTarget)
    }
}

// MARK: - Grid and Layout Helpers
struct GridLayouts {
    
    /// Standard two-column grid for category cards
    static let categoryGrid = [
        GridItem(.flexible(), spacing: AppSpacing.grid.itemSpacing),
        GridItem(.flexible(), spacing: AppSpacing.grid.itemSpacing)
    ]
    
    /// Three-column grid for smaller items
    static let threeColumnGrid = [
        GridItem(.flexible(), spacing: AppSpacing.grid.itemSpacing),
        GridItem(.flexible(), spacing: AppSpacing.grid.itemSpacing),
        GridItem(.flexible(), spacing: AppSpacing.grid.itemSpacing)
    ]
    
    /// Four-column grid for icons or colors
    static let fourColumnGrid = [
        GridItem(.flexible(), spacing: AppSpacing.grid.itemSpacing),
        GridItem(.flexible(), spacing: AppSpacing.grid.itemSpacing),
        GridItem(.flexible(), spacing: AppSpacing.grid.itemSpacing),
        GridItem(.flexible(), spacing: AppSpacing.grid.itemSpacing)
    ]
    
    /// Six-column grid for color palette
    static let sixColumnGrid = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.grid.itemSpacing), count: 6)
    
    /// Two-column grid for style selection
    static let styleGrid = [
        GridItem(.flexible(), spacing: AppSpacing.grid.itemSpacing),
        GridItem(.flexible(), spacing: AppSpacing.grid.itemSpacing)
    ]
    
    /// Two-column grid for folder cards
    static let folderGrid = [
        GridItem(.flexible(), spacing: AppSpacing.grid.itemSpacing),
        GridItem(.flexible(), spacing: AppSpacing.grid.itemSpacing)
    ]
    
    /// Adaptive grid that changes based on screen size
    static func adaptiveGrid(minItemWidth: CGFloat = 150) -> [GridItem] {
        return [GridItem(.adaptive(minimum: minItemWidth), spacing: AppSpacing.grid.itemSpacing)]
    }
}

// MARK: - Preview Provider for Testing Layout
#if DEBUG
struct SpacingPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.sectionSpacing) {
                
                // Spacing Examples
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Spacing Examples")
                        .headlineLarge()
                        .foregroundColor(AppColors.textPrimary)
                    
                    VStack(spacing: AppSpacing.elementSpacing) {
                        HStack {
                            Text("XS (\(Int(AppSpacing.xs))pt)")
                            Spacer()
                            Rectangle().frame(width: AppSpacing.xs, height: 20).foregroundColor(AppColors.primaryBlue)
                        }
                        
                        HStack {
                            Text("SM (\(Int(AppSpacing.sm))pt)")
                            Spacer()
                            Rectangle().frame(width: AppSpacing.sm, height: 20).foregroundColor(AppColors.primaryBlue)
                        }
                        
                        HStack {
                            Text("MD (\(Int(AppSpacing.md))pt)")
                            Spacer()
                            Rectangle().frame(width: AppSpacing.md, height: 20).foregroundColor(AppColors.primaryBlue)
                        }
                        
                        HStack {
                            Text("LG (\(Int(AppSpacing.lg))pt)")
                            Spacer()
                            Rectangle().frame(width: AppSpacing.lg, height: 20).foregroundColor(AppColors.primaryBlue)
                        }
                        
                        HStack {
                            Text("XL (\(Int(AppSpacing.xl))pt)")
                            Spacer()
                            Rectangle().frame(width: AppSpacing.xl, height: 20).foregroundColor(AppColors.primaryBlue)
                        }
                    }
                }
                .cardStyle()
                
                // Touch Target Examples
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Touch Targets")
                        .headlineLarge()
                        .foregroundColor(AppColors.textPrimary)
                    
                    HStack(spacing: AppSpacing.md) {
                        VStack {
                            Circle()
                                .fill(AppColors.primaryBlue)
                                .frame(width: AppSizing.minTouchTarget, height: AppSizing.minTouchTarget)
                            Text("Min (44pt)")
                                .captionLarge()
                        }
                        
                        VStack {
                            Circle()
                                .fill(AppColors.primaryPurple)
                                .frame(width: AppSizing.recommendedTouchTarget, height: AppSizing.recommendedTouchTarget)
                            Text("Recommended (56pt)")
                                .captionLarge()
                        }
                        
                        VStack {
                            Circle()
                                .fill(AppColors.primaryPink)
                                .frame(width: AppSizing.largeTouchTarget, height: AppSizing.largeTouchTarget)
                            Text("Large (64pt)")
                                .captionLarge()
                        }
                    }
                }
                .cardStyle()
                
                // Button Examples
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Button Styles")
                        .headlineLarge()
                        .foregroundColor(AppColors.textPrimary)
                    
                    VStack(spacing: AppSpacing.sm) {
                        Button("Standard Button") {}
                            .buttonStyle()
                        
                        Button("Large Primary Button") {}
                            .largeButtonStyle()
                        
                        Button("Secondary Button") {}
                            .buttonStyle(
                                backgroundColor: AppColors.buttonSecondary,
                                foregroundColor: AppColors.primaryBlue
                            )
                    }
                }
                .cardStyle()
                
                // Corner Radius Examples
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Corner Radius")
                        .headlineLarge()
                        .foregroundColor(AppColors.textPrimary)
                    
                    HStack(spacing: AppSpacing.sm) {
                        VStack {
                            Rectangle()
                                .fill(AppColors.primaryBlue)
                                .frame(width: 60, height: 40)
                                .cornerRadius(AppSizing.cornerRadius.sm)
                            Text("Small")
                                .captionLarge()
                        }
                        
                        VStack {
                            Rectangle()
                                .fill(AppColors.primaryPurple)
                                .frame(width: 60, height: 40)
                                .cornerRadius(AppSizing.cornerRadius.md)
                            Text("Medium")
                                .captionLarge()
                        }
                        
                        VStack {
                            Rectangle()
                                .fill(AppColors.primaryPink)
                                .frame(width: 60, height: 40)
                                .cornerRadius(AppSizing.cornerRadius.lg)
                            Text("Large")
                                .captionLarge()
                        }
                        
                        VStack {
                            Rectangle()
                                .fill(AppColors.buttercup)
                                .frame(width: 60, height: 40)
                                .cornerRadius(AppSizing.cornerRadius.round)
                            Text("Round")
                                .captionLarge()
                        }
                    }
                }
                .cardStyle()
            }
            .pageMargins()
            .padding(.vertical, AppSpacing.sectionSpacing)
        }
        .background(AppColors.backgroundLight)
    }
}

#Preview {
    SpacingPreview()
}
#endif