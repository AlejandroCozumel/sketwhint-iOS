import SwiftUI
import PencilKit
import PhotosUI

struct PaintingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var canvasView = PKCanvasView()
    @State private var selectedImage: UIImage?
    @State private var showingPhotoSourceSelection = false
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var selectedTool: DrawingTool = .marker
    @State private var selectedColor: Color = .black
    @State private var brushWidth: CGFloat = 15
    @State private var drawingHistory: [PKDrawing] = []
    @State private var currentHistoryIndex: Int = -1

    var body: some View {
        ZStack {
            // Background color
            AppColors.backgroundLight
                .ignoresSafeArea()

            if let image = selectedImage {
                VStack(spacing: 0) {
                    // Canvas Area
                    ZStack {
                        // Background image
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)

                        // PencilKit Canvas (only when image is selected)
                        PencilKitCanvas(
                            canvasView: $canvasView,
                            selectedTool: $selectedTool,
                            selectedColor: $selectedColor,
                            brushWidth: $brushWidth,
                            onDrawingChanged: saveToHistory
                        )
                    }

                    // Drawing Tools Bar
                    DrawingToolsBar(
                        selectedTool: $selectedTool,
                        selectedColor: $selectedColor,
                        brushWidth: $brushWidth,
                        canUndo: currentHistoryIndex > 0,
                        onUndo: undo,
                        onClear: clearCanvas
                    )
                }
            } else {
                // Placeholder when no image selected
                VStack(spacing: AppSpacing.lg) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(AppColors.textSecondary)

                    Text("Choose a photo to start painting")
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textSecondary)

                    Button(action: {
                        showingPhotoSourceSelection = true
                    }) {
                        Text("Choose Photo")
                            .font(AppTypography.titleMedium)
                            .foregroundColor(.white)
                            .padding(.horizontal, AppSpacing.xl)
                            .padding(.vertical, AppSpacing.md)
                            .background(AppColors.primaryBlue)
                            .cornerRadius(AppSizing.cornerRadius.md)
                    }
                    .childSafeTouchTarget()
                }
            }
        }
        .navigationTitle("Painting")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(AppColors.primaryBlue)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        showingPhotoSourceSelection = true
                    }) {
                        Label("Choose Image", systemImage: "photo")
                    }

                    Button(action: clearCanvas) {
                        Label("Clear Canvas", systemImage: "trash")
                    }

                    Button(action: {
                        canvasView.drawing = PKDrawing()
                        selectedImage = nil
                    }) {
                        Label("New Canvas", systemImage: "doc")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.primaryBlue)
                }
            }
        }
        .sheet(isPresented: $showingPhotoSourceSelection) {
            PhotoSourceSelectionView(
                showingImagePicker: $showingImagePicker,
                showingCamera: $showingCamera,
                selectedImage: $selectedImage
            )
        }
    }

    private func clearCanvas() {
        canvasView.drawing = PKDrawing()
        saveToHistory()
    }

    private func saveToHistory() {
        // Remove any drawings after current index (for redo functionality)
        if currentHistoryIndex < drawingHistory.count - 1 {
            drawingHistory.removeSubrange((currentHistoryIndex + 1)...)
        }

        // Add current drawing to history
        drawingHistory.append(canvasView.drawing)
        currentHistoryIndex = drawingHistory.count - 1

        // Limit history to last 50 drawings
        if drawingHistory.count > 50 {
            drawingHistory.removeFirst()
            currentHistoryIndex -= 1
        }
    }

    private func undo() {
        guard currentHistoryIndex > 0 else { return }
        currentHistoryIndex -= 1
        canvasView.drawing = drawingHistory[currentHistoryIndex]
    }

    private func redo() {
        guard currentHistoryIndex < drawingHistory.count - 1 else { return }
        currentHistoryIndex += 1
        canvasView.drawing = drawingHistory[currentHistoryIndex]
    }
}

// MARK: - Drawing Tool Enum
enum DrawingTool {
    case pencil
    case pen
    case marker
    case crayon
    case eraser

    var displayName: String {
        switch self {
        case .pencil: return "Pencil"
        case .pen: return "Pen"
        case .marker: return "Marker"
        case .crayon: return "Crayon"
        case .eraser: return "Eraser"
        }
    }

    var inkType: PKInkingTool.InkType {
        switch self {
        case .pencil: return .pencil
        case .pen: return .pen
        case .marker: return .marker
        case .crayon: return .marker
        case .eraser: return .pen // Not used for eraser
        }
    }

    var defaultWidth: CGFloat {
        switch self {
        case .pencil: return 3
        case .pen: return 8
        case .marker: return 20
        case .crayon: return 25
        case .eraser: return 30
        }
    }
}

// MARK: - Drawing Tools Bar
struct DrawingToolsBar: View {
    @Binding var selectedTool: DrawingTool
    @Binding var selectedColor: Color
    @Binding var brushWidth: CGFloat
    let canUndo: Bool
    let onUndo: () -> Void
    let onClear: () -> Void

    // Kid-friendly bright colors (24 colors)
    let colors: [(Color, String)] = [
        // First row - Basics
        (.black, "⚫"), (.white, "⚪"), (.gray, "🩶"),
        // Reds & Pinks
        (.red, "❤️"), (Color(red: 0.8, green: 0, blue: 0), "🔴"), (.pink, "🩷"), (Color(red: 1, green: 0.4, blue: 0.7), "💗"),
        // Oranges & Yellows
        (.orange, "🧡"), (Color(red: 1, green: 0.6, blue: 0), "🟠"), (.yellow, "💛"), (Color(red: 1, green: 0.9, blue: 0.3), "🌟"),
        // Greens
        (.green, "💚"), (Color(red: 0, green: 0.8, blue: 0.4), "🍀"), (Color(red: 0.5, green: 0.8, blue: 0.2), "🌿"), (Color(red: 0, green: 0.5, blue: 0.3), "🌲"),
        // Blues & Cyans
        (.blue, "💙"), (Color(red: 0, green: 0.4, blue: 0.8), "🔵"), (Color(red: 0, green: 0.8, blue: 0.8), "💎"), (Color(red: 0.3, green: 0.7, blue: 1), "🌊"),
        // Purples
        (.purple, "💜"), (Color(red: 0.5, green: 0, blue: 0.5), "🟣"), (Color(red: 0.8, green: 0.4, blue: 1), "🦄"),
        // Browns
        (.brown, "🤎"), (Color(red: 0.6, green: 0.4, blue: 0.2), "🍫")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Drawing Tools Row (Compact)
            HStack(spacing: AppSpacing.xs) {
                MiniToolButton(
                    tool: .pencil,
                    isSelected: selectedTool == .pencil,
                    selectedColor: selectedColor,
                    action: {
                        selectedTool = .pencil
                        brushWidth = selectedTool.defaultWidth
                    }
                )

                MiniToolButton(
                    tool: .pen,
                    isSelected: selectedTool == .pen,
                    selectedColor: selectedColor,
                    action: {
                        selectedTool = .pen
                        brushWidth = selectedTool.defaultWidth
                    }
                )

                MiniToolButton(
                    tool: .marker,
                    isSelected: selectedTool == .marker,
                    selectedColor: selectedColor,
                    action: {
                        selectedTool = .marker
                        brushWidth = selectedTool.defaultWidth
                    }
                )

                MiniToolButton(
                    tool: .crayon,
                    isSelected: selectedTool == .crayon,
                    selectedColor: selectedColor,
                    action: {
                        selectedTool = .crayon
                        brushWidth = selectedTool.defaultWidth
                    }
                )

                MiniToolButton(
                    tool: .eraser,
                    isSelected: selectedTool == .eraser,
                    selectedColor: selectedColor,
                    action: {
                        selectedTool = .eraser
                        brushWidth = selectedTool.defaultWidth
                    }
                )
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColors.backgroundLight)

            Divider()

            // Brush Width Slider (Always visible, compact)
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundColor(AppColors.textSecondary)

                Slider(value: $brushWidth, in: 1...50, step: 1)
                    .tint(AppColors.primaryBlue)

                Image(systemName: "circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.textSecondary)

                // Size preview
                Circle()
                    .fill(selectedTool == .eraser ? Color.pink : selectedColor)
                    .frame(width: min(brushWidth / 3, 14), height: min(brushWidth / 3, 14))

                Text("\(Int(brushWidth))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 22)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.xs)
            .background(AppColors.surfaceLight)

            Divider()

            // Color Palette (Smaller, more colors)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.xs) {
                    ForEach(colors, id: \.1) { color, emoji in
                        Button(action: {
                            selectedColor = color
                        }) {
                            Circle()
                                .fill(color)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .strokeBorder(selectedColor == color ? AppColors.primaryBlue : AppColors.borderLight, lineWidth: selectedColor == color ? 3 : 1)
                                )
                                .overlay(
                                    selectedColor == color ?
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                                    : nil
                                )
                        }
                        .frame(width: 40, height: 40)
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
            }
            .background(AppColors.surfaceLight)
            .frame(height: 50)

            Divider()

            // Bottom Actions
            HStack(spacing: AppSpacing.md) {
                // Undo Button
                Button(action: onUndo) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.uturn.backward.circle.fill")
                            .font(.system(size: 28))
                        Text("Undo")
                            .font(AppTypography.bodyMedium)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(canUndo ? AppColors.primaryBlue : AppColors.textSecondary.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(canUndo ? AppColors.primaryBlue.opacity(0.1) : AppColors.surfaceLight)
                    .cornerRadius(12)
                }
                .disabled(!canUndo)
                .childSafeTouchTarget()

                // Clear Button
                Button(action: onClear) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 28))
                        Text("Clear")
                            .font(AppTypography.bodyMedium)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(AppColors.errorRed)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(AppColors.errorRed.opacity(0.1))
                    .cornerRadius(12)
                }
                .childSafeTouchTarget()
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppColors.backgroundLight)
        }
    }
}

// MARK: - Mini Tool Button (Super Compact)
struct MiniToolButton: View {
    let tool: DrawingTool
    let isSelected: Bool
    let selectedColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if tool == .eraser {
                    // Eraser mockup
                    MiniEraserMockup()
                } else {
                    // Drawing tool mockup
                    MiniDrawingToolMockup(tool: tool, color: selectedColor)
                }
            }
            .frame(width: 50, height: 50)
            .background(isSelected ? AppColors.primaryBlue.opacity(0.15) : AppColors.surfaceLight)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? AppColors.primaryBlue : AppColors.borderLight, lineWidth: isSelected ? 2.5 : 1)
            )
            .cornerRadius(10)
        }
    }
}

// MARK: - Mini Drawing Tool Mockup
struct MiniDrawingToolMockup: View {
    let tool: DrawingTool
    let color: Color

    var body: some View {
        ZStack {
            // Tool body (wood/plastic part)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(
                    LinearGradient(
                        colors: [toolBodyColor, toolBodyColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 5, height: 32)
                .rotationEffect(.degrees(-45))

            // Tool tip (colored part)
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .offset(x: -12, y: 12)

            // Highlight/shine
            RoundedRectangle(cornerRadius: 0.5)
                .fill(.white.opacity(0.3))
                .frame(width: 1.5, height: 28)
                .offset(x: -1)
                .rotationEffect(.degrees(-45))
        }
    }

    var toolBodyColor: Color {
        switch tool {
        case .pencil: return Color(red: 0.95, green: 0.85, blue: 0.6) // Wood color
        case .pen: return Color(red: 0.2, green: 0.2, blue: 0.3) // Dark plastic
        case .marker: return Color(red: 0.9, green: 0.9, blue: 0.9) // Light gray
        case .crayon: return color.opacity(0.8) // Match the color
        case .eraser: return .gray
        }
    }
}

// MARK: - Mini Eraser Mockup
struct MiniEraserMockup: View {
    var body: some View {
        ZStack {
            // Eraser body
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [Color.pink.opacity(0.7), Color.pink.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 22, height: 30)
                .rotationEffect(.degrees(-20))

            // Blue band (typical eraser design)
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.blue.opacity(0.6))
                .frame(width: 22, height: 4)
                .rotationEffect(.degrees(-20))
                .offset(y: -6)

            // Highlight
            RoundedRectangle(cornerRadius: 1.5)
                .fill(.white.opacity(0.4))
                .frame(width: 8, height: 26)
                .rotationEffect(.degrees(-20))
                .offset(x: -5, y: 1)
        }
    }
}

// MARK: - PencilKit Canvas Wrapper
struct PencilKitCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var selectedTool: DrawingTool
    @Binding var selectedColor: Color
    @Binding var brushWidth: CGFloat
    let onDrawingChanged: () -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput // Allows both Apple Pencil and finger
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.delegate = context.coordinator

        // Set initial tool
        updateTool(uiView: canvasView)

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Update tool when settings change
        updateTool(uiView: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged)
    }

    private func updateTool(uiView: PKCanvasView) {
        let uiColor = UIColor(selectedColor)

        switch selectedTool {
        case .pencil, .pen, .marker, .crayon:
            uiView.tool = PKInkingTool(selectedTool.inkType, color: uiColor, width: brushWidth)
        case .eraser:
            uiView.tool = PKEraserTool(.bitmap, width: brushWidth)
        }
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        let onDrawingChanged: () -> Void

        init(onDrawingChanged: @escaping () -> Void) {
            self.onDrawingChanged = onDrawingChanged
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onDrawingChanged()
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        PaintingView()
    }
}
