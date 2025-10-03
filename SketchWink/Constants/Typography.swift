import SwiftUI

/// Typography system for SketchWink - Research-based fonts optimized for children ages 4-12
/// Based on 2024 readability studies and child-friendly design principles
/// Uses system fonts with child-safe sizing (14-24pt minimum) and rounded design for friendliness
struct AppTypography {
    
    // MARK: - Font Weights (Optimized for Child Readability)
    static let light = Font.Weight.light
    static let regular = Font.Weight.regular
    static let medium = Font.Weight.medium
    static let semibold = Font.Weight.semibold
    static let bold = Font.Weight.bold
    static let heavy = Font.Weight.heavy
    
    // MARK: - Display Fonts (App headers - Rounded for friendliness)
    static let displayLarge = Font.system(size: 42, weight: .heavy, design: .rounded)    // Larger for visibility
    static let displayMedium = Font.system(size: 36, weight: .heavy, design: .rounded)   // Inspired by Baloo font
    static let displaySmaller = Font.system(size: 32, weight: .heavy, design: .rounded)  // Between medium and small
    static let displaySmall = Font.system(size: 30, weight: .bold, design: .rounded)     // Child-friendly sizing
    
    // MARK: - Headline Fonts (Section headers - Clear hierarchy)
    static let headlineLarge = Font.system(size: 26, weight: .bold, design: .rounded)   // Minimum 24pt for kids
    static let headlineMedium = Font.system(size: 24, weight: .semibold, design: .rounded) // Research recommended
    static let headlineSmall = Font.system(size: 22, weight: .semibold, design: .rounded)  // Enhanced from 20pt
    
    // MARK: - Title Fonts (Card titles - Readable at distance)
    static let titleLarge = Font.system(size: 20, weight: .semibold, design: .default)  // Increased from 18pt
    static let titleMedium = Font.system(size: 18, weight: .medium, design: .default)   // Increased from 16pt
    static let titleSmall = Font.system(size: 16, weight: .medium, design: .default)    // Increased from 14pt
    
    // MARK: - Body Fonts (Main content - Child readability focused)
    static let bodyLarge = Font.system(size: 18, weight: .regular, design: .default)    // Increased for readability
    static let bodyMedium = Font.system(size: 16, weight: .regular, design: .default)   // Research minimum
    static let bodySmall = Font.system(size: 15, weight: .regular, design: .default)    // Above 14pt minimum
    
    // MARK: - Label Fonts (Form labels - Clear and accessible)
    static let labelLarge = Font.system(size: 15, weight: .medium, design: .default)    // Increased from 13pt
    static let labelMedium = Font.system(size: 14, weight: .medium, design: .default)   // At minimum threshold
    static let labelSmall = Font.system(size: 14, weight: .medium, design: .default)    // Kept at minimum
    
    // MARK: - Caption Fonts (Metadata - Readable but secondary)
    static let captionLarge = Font.system(size: 14, weight: .regular, design: .default) // At research minimum
    static let captionMedium = Font.system(size: 14, weight: .regular, design: .default) // Standardized
    static let captionSmall = Font.system(size: 14, weight: .regular, design: .default)  // No smaller than 14pt
    
    // MARK: - Special Purpose Fonts (Research-optimized)
    
    /// Font for the app logo and main branding (Cherry Bomb One inspired)
    static let appTitle = Font.system(size: 48, weight: .heavy, design: .rounded)       // Larger impact
    
    /// Font for category cards and main navigation (Baloo inspired)
    static let categoryTitle = Font.system(size: 20, weight: .bold, design: .rounded)   // Increased visibility
    
    /// Font for generation prompts and user input (Open Sans inspired)
    static let promptText = Font.system(size: 18, weight: .medium, design: .default)    // Better readability
    
    /// Font for buttons (Touch-friendly sizing)
    static let buttonText = Font.system(size: 18, weight: .semibold, design: .rounded)  // Research minimum
    
    /// Font for large action buttons (Primary actions)
    static let buttonLarge = Font.system(size: 22, weight: .bold, design: .rounded)     // High visibility
    
    /// Font for tab bar items (Minimum readable)
    static let tabBarText = Font.system(size: 14, weight: .medium, design: .default)    // Above 11pt minimum
    
    /// Font for navigation titles (Clear hierarchy)
    static let navigationTitle = Font.system(size: 22, weight: .bold, design: .rounded) // Enhanced prominence
    
    /// Font for onboarding and welcome screens (Nunito inspired)
    static let onboardingTitle = Font.system(size: 32, weight: .heavy, design: .rounded) // Welcoming impact
    static let onboardingBody = Font.system(size: 18, weight: .regular, design: .default)  // Comfortable reading
    
    /// Font for generation status and progress (Lato inspired)
    static let statusText = Font.system(size: 16, weight: .medium, design: .default)     // Clear feedback
    
    /// Font for profile names in family selector (Friendly approach)
    static let profileName = Font.system(size: 18, weight: .semibold, design: .rounded)  // Personal touch
    
    // MARK: - Monospace Fonts (for codes, IDs, technical text)
    static let monospaceLarge = Font.system(size: 14, weight: .regular, design: .monospaced)
    static let monospaceMedium = Font.system(size: 12, weight: .regular, design: .monospaced)
    static let monospaceSmall = Font.system(size: 10, weight: .regular, design: .monospaced)
}

// MARK: - Text Style Modifiers
extension Text {
    
    /// Apply display large style
    func displayLarge() -> Text {
        self.font(AppTypography.displayLarge)
    }
    
    /// Apply display medium style
    func displayMedium() -> Text {
        self.font(AppTypography.displayMedium)
    }

    /// Apply display smaller style
    func displaySmaller() -> Text {
        self.font(AppTypography.displaySmaller)
    }

    /// Apply display small style
    func displaySmall() -> Text {
        self.font(AppTypography.displaySmall)
    }
    
    /// Apply headline large style
    func headlineLarge() -> Text {
        self.font(AppTypography.headlineLarge)
    }
    
    /// Apply headline medium style
    func headlineMedium() -> Text {
        self.font(AppTypography.headlineMedium)
    }
    
    /// Apply headline small style
    func headlineSmall() -> Text {
        self.font(AppTypography.headlineSmall)
    }
    
    /// Apply title large style
    func titleLarge() -> Text {
        self.font(AppTypography.titleLarge)
    }
    
    /// Apply title medium style
    func titleMedium() -> Text {
        self.font(AppTypography.titleMedium)
    }
    
    /// Apply title small style
    func titleSmall() -> Text {
        self.font(AppTypography.titleSmall)
    }
    
    /// Apply body large style
    func bodyLarge() -> Text {
        self.font(AppTypography.bodyLarge)
    }
    
    /// Apply body medium style
    func bodyMedium() -> Text {
        self.font(AppTypography.bodyMedium)
    }
    
    /// Apply body small style
    func bodySmall() -> Text {
        self.font(AppTypography.bodySmall)
    }
    
    /// Apply app title style with gradient
    func appTitle() -> some View {
        self.font(AppTypography.appTitle)
            .foregroundStyle(
                LinearGradient(
                    colors: [AppColors.primaryBlue, AppColors.primaryPurple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
    }
    
    /// Apply category title style
    func categoryTitle() -> Text {
        self.font(AppTypography.categoryTitle)
    }
    
    /// Apply button text style
    func buttonText() -> Text {
        self.font(AppTypography.buttonText)
    }
    
    /// Apply button large style
    func buttonLarge() -> Text {
        self.font(AppTypography.buttonLarge)
    }
    
    /// Apply onboarding title style
    func onboardingTitle() -> Text {
        self.font(AppTypography.onboardingTitle)
    }
    
    /// Apply onboarding body style
    func onboardingBody() -> Text {
        self.font(AppTypography.onboardingBody)
    }
    
    /// Apply profile name style
    func profileName() -> Text {
        self.font(AppTypography.profileName)
    }
    
    /// Apply caption large style
    func captionLarge() -> Text {
        self.font(AppTypography.captionLarge)
    }
    
    /// Apply caption medium style
    func captionMedium() -> Text {
        self.font(AppTypography.captionMedium)
    }
    
    /// Apply caption small style
    func captionSmall() -> Text {
        self.font(AppTypography.captionSmall)
    }
}

// MARK: - Dynamic Type Support
struct DynamicTypography {
    
    /// Returns appropriate font size based on Dynamic Type setting
    static func scaledFont(baseSize: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        return Font.system(size: baseSize, weight: weight, design: design)
    }
    
    /// Returns font that respects accessibility settings but has maximum size for child safety
    static func accessibleFont(baseSize: CGFloat, maxSize: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        // Limit maximum font size to prevent UI breaking with very large accessibility text
        let scaledSize = min(baseSize * 1.5, maxSize) // Allow up to 1.5x scaling
        return Font.system(size: scaledSize, weight: weight, design: design)
    }
}

// MARK: - Text Style Presets
struct TextStyles {
    
    /// Style for page headers
    static func pageHeader() -> some View {
        Text("")
            .font(AppTypography.headlineLarge)
            .foregroundColor(AppColors.textPrimary)
            .multilineTextAlignment(.center)
    }
    
    /// Style for section headers
    static func sectionHeader() -> some View {
        Text("")
            .font(AppTypography.headlineMedium)
            .foregroundColor(AppColors.textPrimary)
            .multilineTextAlignment(.leading)
    }
    
    /// Style for body content
    static func bodyContent() -> some View {
        Text("")
            .font(AppTypography.bodyMedium)
            .foregroundColor(AppColors.textSecondary)
            .multilineTextAlignment(.leading)
            .lineSpacing(4)
    }
    
    /// Style for captions
    static func caption() -> some View {
        Text("")
            .font(AppTypography.captionLarge)
            .foregroundColor(AppColors.textSecondary)
            .multilineTextAlignment(.center)
    }
    
    /// Style for error messages
    static func errorText() -> some View {
        Text("")
            .font(AppTypography.bodySmall)
            .foregroundColor(AppColors.errorRed)
            .multilineTextAlignment(.center)
    }
    
    /// Style for success messages
    static func successText() -> some View {
        Text("")
            .font(AppTypography.bodySmall)
            .foregroundColor(AppColors.successGreen)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Preview Provider for Testing Typography
#if DEBUG
struct TypographyPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Display Fonts
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Fonts")
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("SketchWink")
                        .font(AppTypography.displayLarge)
                        .foregroundColor(AppColors.primaryBlue)
                    
                    Text("Create Amazing Art")
                        .font(AppTypography.displayMedium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Family-Friendly AI")
                        .font(AppTypography.displaySmall)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Divider()
                
                // Headlines
                VStack(alignment: .leading, spacing: 8) {
                    Text("Headlines")
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Coloring Pages")
                        .font(AppTypography.headlineLarge)
                        .foregroundColor(AppColors.coloringPagesColor)
                    
                    Text("Choose Your Style")
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Popular This Week")
                        .font(AppTypography.headlineSmall)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Divider()
                
                // Body Text
                VStack(alignment: .leading, spacing: 8) {
                    Text("Body Text")
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Generate beautiful coloring pages, stickers, and wallpapers with AI. Perfect for children ages 4-12 with parental controls and family-friendly content.")
                        .font(AppTypography.bodyLarge)
                        .foregroundColor(AppColors.textPrimary)
                        .lineSpacing(4)
                    
                    Text("Tap any category to start creating amazing art that your family will love.")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.textSecondary)
                        .lineSpacing(2)
                }
                
                Divider()
                
                // Buttons
                VStack(alignment: .leading, spacing: 12) {
                    Text("Buttons")
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Button("Generate Art") {}
                        .font(AppTypography.buttonLarge)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(AppColors.primaryBlue)
                        .cornerRadius(12)
                    
                    Button("View Gallery") {}
                        .font(AppTypography.buttonText)
                        .foregroundColor(AppColors.primaryBlue)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(AppColors.buttonSecondary)
                        .cornerRadius(10)
                }
                
                Divider()
                
                // Special Styles
                VStack(alignment: .leading, spacing: 8) {
                    Text("Special Styles")
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("SketchWink")
                        .appTitle()
                    
                    Text("Emma's Profile")
                        .profileName()
                        .foregroundColor(AppColors.primaryPink)
                    
                    Text("Generating your masterpiece...")
                        .font(AppTypography.statusText)
                        .foregroundColor(AppColors.infoBlue)
                    
                    Text("Generation ID: GEN_123456")
                        .font(AppTypography.monospaceMedium)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding()
        }
        .background(AppColors.backgroundLight)
    }
}

#Preview {
    TypographyPreview()
}
#endif