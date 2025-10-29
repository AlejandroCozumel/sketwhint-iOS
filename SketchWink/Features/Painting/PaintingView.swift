import SwiftUI
import PencilKit
import PhotosUI
import Photos

struct PaintingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var canvasView = PKCanvasView()
    @State private var selectedImage: UIImage?
    @State private var showingPhotoSourceSelection = false
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingSaveAlert = false
    @State private var saveSuccessMessage: String?
    @State private var isSaving = false
    @State private var canvasID = UUID()

    var body: some View {
        ZStack {
            // Background color
            AppColors.backgroundLight
                .ignoresSafeArea()

            if let image = selectedImage {
                ZStack {
                    // Background image
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)

                    // Native PencilKit Canvas
                    NativePencilKitCanvas(
                        canvasView: $canvasView,
                        backgroundImage: image
                    )
                    .id(canvasID)
                }
                .id(selectedImage) // Force complete recreation when image changes
                .onChange(of: selectedImage) { oldValue, newValue in
                    if newValue != nil {
                        print("🎨 Image selected, recreating canvas")

                        // Force canvas recreation with new ID
                        canvasID = UUID()
                    }
                }
                .onChange(of: canvasID) { oldValue, newValue in
                    // Restore tool picker when canvas recreates
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        print("🔄 Canvas ID changed, restoring tool picker")
                        showToolPicker()
                    }
                }
            } else {
                // Placeholder when no image selected
                VStack(spacing: AppSpacing.lg) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 60))
                        .foregroundColor(AppColors.textSecondary)

                    Text(String(localized: "painting.choose.photo.prompt"))
                        .font(AppTypography.titleMedium)
                        .foregroundColor(AppColors.textSecondary)

                    Button {
                        showingPhotoSourceSelection = true
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "photo.badge.plus")
                            Text(String(localized: "painting.choose.photo"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .largeButtonStyle(backgroundColor: AppColors.primaryBlue)
                }
                .padding(.horizontal, AppSpacing.lg)
            }
        }
        .navigationTitle(String(localized: "painting.title"))
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
                        Label(String(localized: "painting.menu.choose.image"), systemImage: "photo")
                    }

                    Button(action: {
                        clearCanvas()
                    }) {
                        Label(String(localized: "painting.menu.clear.canvas"), systemImage: "trash")
                    }

                    Button(action: {
                        canvasView.drawing = PKDrawing()
                        selectedImage = nil
                    }) {
                        Label(String(localized: "painting.menu.new.canvas"), systemImage: "doc")
                    }

                    Button(action: {
                        saveToGallery()
                    }) {
                        Label(isSaving ? String(localized: "painting.menu.saving") : String(localized: "painting.menu.save.gallery"), systemImage: "square.and.arrow.down")
                    }
                    .disabled(isSaving || selectedImage == nil)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.primaryBlue)
                }
            }
        }
        .sheet(isPresented: $showingPhotoSourceSelection, onDismiss: {
            // Restore tool picker when sheet dismisses
            if selectedImage != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🔄 Sheet dismissed, restoring tool picker")
                    showToolPicker()
                }
            }
        }) {
            PhotoSourceSelectionView(
                showingImagePicker: $showingImagePicker,
                showingCamera: $showingCamera,
                selectedImage: $selectedImage
            )
        }
        .alert(String(localized: "painting.alert.save.title"), isPresented: $showingSaveAlert) {
            Button(String(localized: "common.cancel"), role: .cancel) { }
            Button(String(localized: "common.save")) {
                performSave()
            }
        } message: {
            Text(String(localized: "painting.alert.save.message"))
        }
        .alert(String(localized: "common.success"), isPresented: .constant(saveSuccessMessage != nil)) {
            Button(String(localized: "common.ok")) {
                saveSuccessMessage = nil
            }
        } message: {
            Text(saveSuccessMessage ?? "")
        }
    }

    private func clearCanvas() {
        canvasView.drawing = PKDrawing()
    }

    private func saveToGallery() {
        showingSaveAlert = true
    }

    private func showToolPicker() {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else {
            print("❌ No key window found")
            return
        }

        print("✅ Window found, showing tool picker")
        let toolPicker = PKToolPicker.shared(for: window)
        toolPicker?.setVisible(true, forFirstResponder: canvasView)
        canvasView.becomeFirstResponder()
        print("✅ Tool picker visibility set, canvas became first responder")
    }

    private func performSave() {
        guard let image = selectedImage else { return }

        isSaving = true

        // Get the canvas bounds
        let canvasBounds = canvasView.bounds

        // Create a renderer with the canvas size
        let renderer = UIGraphicsImageRenderer(size: canvasBounds.size)
        let finalImage = renderer.image { context in
            // Fill with white background first
            UIColor.white.setFill()
            context.fill(canvasBounds)

            // Draw the background image scaled to fit canvas
            image.draw(in: canvasBounds)

            // Draw the canvas drawing on top
            let drawing = canvasView.drawing
            drawing.image(from: canvasBounds, scale: UIScreen.main.scale).draw(in: canvasBounds)
        }

        // Save to photo library using Photos framework
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: finalImage)
        }) { success, error in
            DispatchQueue.main.async {
                self.isSaving = false
                if let error = error {
                    self.saveSuccessMessage = String(localized: "painting.save.failed") + ": \(error.localizedDescription)"
                } else if success {
                    self.saveSuccessMessage = String(localized: "painting.save.success")
                }
            }
        }
    }
}

// MARK: - Native PencilKit Canvas Wrapper
struct NativePencilKitCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    let backgroundImage: UIImage

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput // Allows both Apple Pencil and finger
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.delegate = context.coordinator

        print("🎨 makeUIView called - creating canvas")

        // Setup tool picker immediately
        context.coordinator.setupToolPicker(for: canvasView)

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Don't re-setup on every update, only on makeUIView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        private var hasRestoredAfterInteraction = false

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // User started drawing, ensure tool picker is visible
            if !hasRestoredAfterInteraction {
                print("✏️ Drawing detected, restoring tool picker")
                restoreToolPicker(for: canvasView)
                hasRestoredAfterInteraction = true

                // Reset flag after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.hasRestoredAfterInteraction = false
                }
            }
        }

        func restoreToolPicker(for canvasView: PKCanvasView) {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }) else {
                return
            }

            let toolPicker = PKToolPicker.shared(for: window)
            canvasView.becomeFirstResponder()
            toolPicker?.setVisible(true, forFirstResponder: canvasView)
        }

        func setupToolPicker(for canvasView: PKCanvasView) {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }) else {
                print("❌ Coordinator: No key window")
                return
            }

            print("✅ Coordinator: Setting up tool picker")
            let toolPicker = PKToolPicker.shared(for: window)

            if toolPicker == nil {
                print("❌ Coordinator: Tool picker is nil!")
                return
            }

            // Always add observer (PKCanvasView handles duplicates internally)
            toolPicker?.addObserver(canvasView)

            print("✅ Coordinator: Observer added")

            // Delay becoming first responder to ensure view is in hierarchy and sheets are dismissed
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("🎨 Coordinator: Making canvas first responder")

                canvasView.becomeFirstResponder()
                toolPicker?.setVisible(true, forFirstResponder: canvasView)

                print("✅ Coordinator: Canvas is first responder: \(canvasView.isFirstResponder)")
                print("✅ Coordinator: Tool picker visible: \(toolPicker?.isVisible ?? false)")
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        PaintingView()
    }
}
