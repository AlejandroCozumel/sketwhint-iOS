import SwiftUI

struct ColoringView: View {
    let sourceImage: UIImage
    let originalPrompt: String
    let onDismiss: () -> Void
    
    @State private var drawnPaths: [DrawnPath] = []
    @State private var currentPath = Path()
    @State private var selectedColor = Color.red
    @State private var brushSize: CGFloat = 8.0
    @State private var isDrawing = false
    @Environment(\.dismiss) private var dismiss
    
    // Color palette for kids
    private let colorPalette: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink,
        .brown, .gray, .black,
        Color(red: 1, green: 0.6, blue: 0.8),      // Light pink
        Color(red: 0.6, green: 1, blue: 0.6),      // Light green
        Color(red: 0.6, green: 0.8, blue: 1),      // Light blue
        Color(red: 1, green: 1, blue: 0.6),        // Light yellow
        Color(red: 0.8, green: 0.6, blue: 1),      // Light purple
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: AppSpacing.md) {
                
                // Color palette
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(Array(colorPalette.enumerated()), id: \.offset) { index, color in
                            Circle()
                                .fill(color)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == color ? AppColors.textPrimary : Color.clear, lineWidth: 3)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                                .childSafeTouchTarget()
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                }
                
                // Brush size slider
                VStack(spacing: AppSpacing.xs) {
                    Text("Brush Size: \(Int(brushSize))")
                        .font(AppTypography.titleSmall)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Slider(value: $brushSize, in: 2...20, step: 1)
                        .tint(AppColors.primaryBlue)
                        .padding(.horizontal, AppSpacing.md)
                }
                
                // Drawing canvas
                ZStack {
                    // Background coloring page
                    Image(uiImage: sourceImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .allowsHitTesting(false)
                    
                    // Drawing overlay
                    Canvas { context, size in
                        // Draw completed paths
                        for path in drawnPaths {
                            context.stroke(
                                path.path,
                                with: .color(path.color),
                                style: StrokeStyle(
                                    lineWidth: path.lineWidth,
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )
                        }
                        
                        // Draw current path being drawn
                        if isDrawing {
                            context.stroke(
                                currentPath,
                                with: .color(selectedColor),
                                style: StrokeStyle(
                                    lineWidth: brushSize,
                                    lineCap: .round,
                                    lineJoin: .round
                                )
                            )
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isDrawing {
                                    isDrawing = true
                                    currentPath = Path()
                                    currentPath.move(to: value.location)
                                } else {
                                    currentPath.addLine(to: value.location)
                                }
                            }
                            .onEnded { _ in
                                finishStroke()
                            }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .cornerRadius(AppSizing.cornerRadius.md)
                .shadow(
                    color: Color.black.opacity(0.1),
                    radius: 5,
                    x: 0,
                    y: 2
                )
                
                // Controls
                HStack(spacing: AppSpacing.md) {
                    Button("Undo") {
                        undoLastStroke()
                    }
                    .largeButtonStyle(backgroundColor: AppColors.buttonSecondary)
                    .disabled(drawnPaths.isEmpty)
                    
                    Button("Clear All") {
                        clearAll()
                    }
                    .largeButtonStyle(backgroundColor: AppColors.errorRed)
                    .disabled(drawnPaths.isEmpty)
                    
                    Button("Save") {
                        saveColoredImage()
                    }
                    .largeButtonStyle(backgroundColor: AppColors.coloringPagesColor)
                    .disabled(drawnPaths.isEmpty)
                }
                .childSafeTouchTarget()
            }
            .pageMargins()
            .padding(.vertical, AppSpacing.md)
            .background(AppColors.backgroundLight)
            .navigationTitle("Color Your Art")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                        onDismiss()
                    }
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.primaryBlue)
                }
            }
        }
    }
    
    // MARK: - Drawing Methods
    private func finishStroke() {
        guard isDrawing else { return }
        
        drawnPaths.append(DrawnPath(
            path: currentPath,
            color: selectedColor,
            lineWidth: brushSize
        ))
        
        currentPath = Path()
        isDrawing = false
    }
    
    private func undoLastStroke() {
        guard !drawnPaths.isEmpty else { return }
        drawnPaths.removeLast()
    }
    
    private func clearAll() {
        drawnPaths.removeAll()
        currentPath = Path()
        isDrawing = false
    }
    
    private func saveColoredImage() {
        // Create a renderer to capture the complete colored image
        let renderer = ImageRenderer(content: renderableContent())
        renderer.scale = 3.0 // High quality for saving
        
        if let uiImage = renderer.uiImage {
            // Save to Photos Library
            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
            
            // Show success feedback
            // You could add a toast notification here
        }
    }
    
    @ViewBuilder
    private func renderableContent() -> some View {
        ZStack {
            Image(uiImage: sourceImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
            
            Canvas { context, size in
                for path in drawnPaths {
                    context.stroke(
                        path.path,
                        with: .color(path.color),
                        style: StrokeStyle(
                            lineWidth: path.lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }
            }
        }
    }
}

// MARK: - Drawing Path Model
struct DrawnPath {
    let path: Path
    let color: Color
    let lineWidth: CGFloat
}

// MARK: - Preview
#if DEBUG
struct ColoringView_Previews: PreviewProvider {
    static var previews: some View {
        ColoringView(
            sourceImage: UIImage(systemName: "heart") ?? UIImage(),
            originalPrompt: "cute cat playing with yarn",
            onDismiss: {}
        )
    }
}
#endif