import SwiftUI

/// Color palette for SketchWink - Family-friendly AI creative platform
/// Research-based colors designed for children ages 4-12 with accessibility and modern design trends
/// Based on 2024 child-friendly design principles and color psychology
struct AppColors {
    
    // MARK: - Primary Brand Colors (Modern & Vibrant)
    static let primaryBlue = Color(hex: "#37B6F6")        // Picton Blue - Bright, friendly blue
    static let primaryPurple = Color(hex: "#882FF6")      // Blue-Violet - Creative and magical
    static let primaryPink = Color(hex: "#FF6B9D")        // Bubblegum Pink - Playful and warm
    
    // MARK: - Content Category Colors (Vibrant & Safe)
    static let coloringPagesColor = Color(hex: "#F99D07")  // RYB Orange - Warm and creative
    static let stickersColor = Color(hex: "#35D461")       // UFO Green - Fresh and energetic  
    static let wallpapersColor = Color(hex: "#9B59B6")     // Amethyst Purple - Dreamy and artistic
    static let mandalasColor = Color(hex: "#00D4AA")       // Turquoise - Calming and zen
    
    // MARK: - Pastel Accent Colors (2024 Dopamine Decor Trend)
    static let softMint = Color(hex: "#A8E6CF")           // Mint Green - Fresh and soothing
    static let babyBlue = Color(hex: "#B3E5FC")           // Baby Blue - Calm and trustworthy  
    static let lavenderMist = Color(hex: "#D1C4E9")       // Soft Lavender - Peaceful and creative
    static let peachCream = Color(hex: "#FFCCBC")         // Peach - Warm and friendly
    static let buttercup = Color(hex: "#F9E104")          // Vivid Yellow - Sunshine and joy
    static let cottonCandy = Color(hex: "#F8BBD9")        // Light Pink - Sweet and gentle
    
    // MARK: - Bright Accent Colors (Energy & Fun)
    static let energyOrange = Color(hex: "#FF9500")       // Bright Orange - Enthusiasm
    static let limeGreen = Color(hex: "#32D74B")          // Lime Green - Nature and growth
    static let skyBlue = Color(hex: "#007AFF")            // iOS Blue - Familiar and trusted
    static let sunflower = Color(hex: "#FFCC02")          // Sunflower Yellow - Happiness
    static let coral = Color(hex: "#FF6B6B")              // Living Coral - Warmth and energy
    static let aqua = Color(hex: "#1DD1A1")               // Aqua - Refreshing and modern
    
    // MARK: - Neutral Colors
    static let backgroundLight = Color(red: 0.98, green: 0.98, blue: 1.0)    // #FAFAFF - Very light blue
    static let backgroundDark = Color(red: 0.05, green: 0.05, blue: 0.1)     // #0D0D1A - Dark blue
    static let surfaceLight = Color.white                                     // #FFFFFF - Pure white
    static let surfaceDark = Color(red: 0.1, green: 0.1, blue: 0.15)         // #1A1A26 - Dark surface
    
    // MARK: - Text Colors
    static let textPrimary = Color(red: 0.1, green: 0.1, blue: 0.2)          // #1A1A33 - Dark blue text
    static let textSecondary = Color(red: 0.4, green: 0.4, blue: 0.5)        // #666680 - Gray text
    static let textOnDark = Color.white                                       // #FFFFFF - White text
    static let textOnColor = Color.white                                      // #FFFFFF - White text on colors
    
    // MARK: - State Colors
    static let successGreen = Color(red: 0.2, green: 0.8, blue: 0.4)         // #33CC66 - Success
    static let warningOrange = Color(red: 1.0, green: 0.6, blue: 0.2)        // #FF9933 - Warning
    static let errorRed = Color(red: 1.0, green: 0.3, blue: 0.4)             // #FF4D66 - Error
    static let infoBlue = Color(red: 0.3, green: 0.7, blue: 1.0)             // #4DB3FF - Information
    
    // MARK: - Interactive Colors
    static let buttonPrimary = primaryBlue
    static let buttonSecondary = Color(red: 0.9, green: 0.9, blue: 0.95)     // #E6E6F2 - Light gray
    static let buttonDisabled = Color(red: 0.8, green: 0.8, blue: 0.85)      // #CCCCDA - Disabled gray
    
    // MARK: - Border Colors
    static let borderLight = Color(red: 0.9, green: 0.9, blue: 0.95)         // #E6E6F2 - Light border
    static let borderMedium = Color(red: 0.8, green: 0.8, blue: 0.85)        // #CCCCDA - Medium border
    static let borderDark = Color(red: 0.6, green: 0.6, blue: 0.7)           // #99999B - Dark border
    
    // MARK: - Coloring Palette Colors (Research-based for digital coloring)
    static let coloringPalette: [Color] = [
        // Primary vibrant colors
        coral,              // Living Coral - warm red
        energyOrange,       // Bright Orange - energy
        buttercup,          // Vivid Yellow - sunshine
        limeGreen,          // Nature green - growth
        skyBlue,            // iOS Blue - familiar
        primaryPurple,      // Blue-Violet - creativity
        primaryPink,        // Bubblegum Pink - playful
        
        // Pastel colors (2024 trend)
        cottonCandy,        // Light Pink - gentle
        peachCream,         // Peach - warm
        softMint,           // Mint Green - soothing
        babyBlue,           // Baby Blue - calm
        lavenderMist,       // Soft Lavender - peaceful
        sunflower,          // Sunflower Yellow - happiness
        
        // Nature and earth tones
        Color(hex: "#8B4513"),  // Saddle Brown
        Color(hex: "#D2B48C"),  // Tan
        Color(hex: "#A0522D"),  // Sienna
        aqua,               // Refreshing turquoise
        
        // Essential neutrals
        Color.black,
        Color(hex: "#6C757D"),  // Medium Gray
        Color(hex: "#E9ECEF"),  // Light Gray
        Color.white
    ]
    
    // MARK: - Collection Colors (Modern palette for user organization)
    static let collectionColors: [Color] = [
        primaryBlue,        // Picton Blue
        primaryPurple,      // Blue-Violet
        primaryPink,        // Bubblegum Pink
        coloringPagesColor, // RYB Orange
        stickersColor,      // UFO Green
        wallpapersColor,    // Amethyst Purple
        mandalasColor,      // Turquoise
        coral,              // Living Coral
        softMint,           // Mint Green
        lavenderMist,       // Soft Lavender
        peachCream,         // Peach
        aqua                // Aqua
    ]
}

// MARK: - Color Extensions for Convenience
extension Color {
    
    /// Creates a color from hex string
    /// - Parameter hex: Hex string (e.g., "#FF6B6B" or "FF6B6B")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Returns a lighter version of the color by increasing opacity
    func lighter(by percentage: Double = 0.2) -> Color {
        return self.opacity(1.0 - percentage)
    }
    
    /// Returns a darker version of the color by reducing brightness
    func darker(by percentage: Double = 0.2) -> Color {
        // Simple darkening by reducing opacity - for more advanced darkening, 
        // you would need to convert to HSB and reduce brightness
        return Color.black.opacity(percentage)
    }
}

// MARK: - Preview Provider for Testing Colors
#if DEBUG
struct ColorsPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // Primary Colors
                VStack(alignment: .leading, spacing: 8) {
                    Text("Primary Brand Colors")
                        .font(.headline)
                        .padding(.leading)
                    
                    HStack(spacing: 12) {
                        ColorSwatch(color: AppColors.primaryBlue, name: "Primary Blue")
                        ColorSwatch(color: AppColors.primaryPurple, name: "Primary Purple")
                        ColorSwatch(color: AppColors.primaryPink, name: "Primary Pink")
                    }
                    .padding(.horizontal)
                }
                
                // Category Colors
                VStack(alignment: .leading, spacing: 8) {
                    Text("Content Category Colors")
                        .font(.headline)
                        .padding(.leading)
                    
                    HStack(spacing: 12) {
                        ColorSwatch(color: AppColors.coloringPagesColor, name: "Coloring")
                        ColorSwatch(color: AppColors.stickersColor, name: "Stickers")
                        ColorSwatch(color: AppColors.wallpapersColor, name: "Wallpapers")
                        ColorSwatch(color: AppColors.mandalasColor, name: "Mandalas")
                    }
                    .padding(.horizontal)
                }
                
                // Accent Colors
                VStack(alignment: .leading, spacing: 8) {
                    Text("Child-Friendly Accents")
                        .font(.headline)
                        .padding(.leading)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                        ColorSwatch(color: AppColors.buttercup, name: "Buttercup")
                        ColorSwatch(color: AppColors.limeGreen, name: "Lime Green")
                        ColorSwatch(color: AppColors.skyBlue, name: "Sky Blue")
                        ColorSwatch(color: AppColors.coral, name: "Coral")
                        ColorSwatch(color: AppColors.lavenderMist, name: "Lavender Mist")
                        ColorSwatch(color: AppColors.softMint, name: "Soft Mint")
                    }
                    .padding(.horizontal)
                }
                
                // Coloring Palette
                VStack(alignment: .leading, spacing: 8) {
                    Text("Digital Coloring Palette")
                        .font(.headline)
                        .padding(.leading)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                        ForEach(0..<AppColors.coloringPalette.count, id: \.self) { index in
                            Circle()
                                .fill(AppColors.coloringPalette[index])
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(AppColors.backgroundLight)
    }
}

struct ColorSwatch: View {
    let color: Color
    let name: String
    
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(color)
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.borderLight, lineWidth: 1)
                )
            
            Text(name)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    ColorsPreview()
}
#endif