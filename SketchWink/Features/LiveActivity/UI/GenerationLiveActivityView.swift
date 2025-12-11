import ActivityKit
import WidgetKit
import SwiftUI

public struct GenerationLiveActivityView: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: GenerationAttributes.self) { context in
            // Lock Screen / Banner UI
            GenerationLockScreenBanner(context: context)
                .widgetURL(URL(string: "sketchwink://open-story?id=\(context.attributes.generationId)&type=\(context.attributes.type.rawValue)"))
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    HStack {
                        if let url = context.attributes.thumbnailUrl {
                            // In a real widget, async image loading is tricky.
                            // Usually we pass the image data or file path.
                            Image(systemName: context.attributes.type == .book ? "book.closed.fill" : "moon.stars.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.leading)
                    .dynamicIsland(verticalPlacement: .belowIfTooWide)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Label {
                        Text("\(Int(context.state.progress * 100))%")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    } icon: {
                        Image(systemName: "percent")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.trailing)
                    .dynamicIsland(verticalPlacement: .belowIfTooWide)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.storyTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(context.state.currentStep)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        
                        // Custom Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 6)
                                
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [hexColor("#6366F1"), hexColor("#EC4899")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * context.state.progress, height: 6)
                            }
                        }
                        .frame(height: 6)
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            } compactLeading: {
                Image(systemName: context.attributes.type == .book ? "book.fill" : "moon.stars.fill")
                    .foregroundColor(hexColor("#6366F1"))
            } compactTrailing: {
                // Circular progress for compact state
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    
                    Circle()
                        .trim(from: 0, to: context.state.progress)
                        .stroke(hexColor("#EC4899"), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 20, height: 20)
            } minimal: {
                Image(systemName: "sparkles")
                    .foregroundColor(hexColor("#EC4899"))
            }
            .keylineTint(hexColor("#6366F1"))
            .widgetURL(URL(string: "sketchwink://open-story?id=\(context.attributes.generationId)&type=\(context.attributes.type.rawValue)"))
        }
    }
}

// Separate component for Lock Screen to keep code clean
struct GenerationLockScreenBanner: View {
    let context: ActivityViewContext<GenerationAttributes>
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                // Icon
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [hexColor("#6366F1"), hexColor("#8B5CF6")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: context.attributes.type == .book ? "book.fill" : "moon.stars.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                }
                
                VStack(alignment: .leading) {
                    Text(context.attributes.storyTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(context.state.currentStep)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Text("\(Int(context.state.progress * 100))%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 8)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [hexColor("#6366F1"), hexColor("#EC4899")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * context.state.progress, height: 8)
                        .animation(.spring(), value: context.state.progress)
                }
            }
            .frame(height: 8)
            .padding(.top, 8)
        }
        .padding()
        // Liquid Glass Background
        .background(Color.black.opacity(0.6))
    }
}

// Local helper to avoid extension conflicts
private func hexColor(_ hex: String) -> Color {
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
    return Color(
        .sRGB,
        red: Double(r) / 255,
        green: Double(g) / 255,
        blue: Double(b) / 255,
        opacity: Double(a) / 255
    )
}
