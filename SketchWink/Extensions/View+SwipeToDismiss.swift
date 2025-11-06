//
//  View+SwipeToDismiss.swift
//  SketchWink
//
//  Adds swipe-down-to-dismiss functionality for full-screen covers
//

import SwiftUI

extension View {
    /// Adds a swipe-down gesture to dismiss full-screen covers (child-friendly)
    /// Works with @Environment(\.dismiss) in the presented view
    func swipeToDismiss() -> some View {
        modifier(SwipeToDismissModifier())
    }

    /// Full-screen cover with built-in swipe-to-dismiss (global component)
    func dismissableFullScreenCover<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        fullScreenCover(isPresented: isPresented, onDismiss: onDismiss) {
            content()
                .swipeToDismiss()
        }
    }

    /// Full-screen cover with built-in swipe-to-dismiss (with item)
    func dismissableFullScreenCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        fullScreenCover(item: item, onDismiss: onDismiss) { item in
            content(item)
                .swipeToDismiss()
        }
    }
}

private struct SwipeToDismissModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @State private var dragAmount: CGFloat = 0

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            // Drag handle area - only this area is interactive for swipe
            DragHandleArea(dragAmount: $dragAmount, onDismiss: {
                dismiss()
            })

            // Main content with iPad horizontal padding
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .iPadContentPadding() // Auto-apply iPad padding to all sheet content
        }
        .background(AppColors.backgroundLight) // Consistent background for all sheets
        .ignoresSafeArea() // Extend background to edges
    }
}

private struct DragHandleArea: View {
    @Binding var dragAmount: CGFloat
    let onDismiss: () -> Void

    @State private var isDragging = false

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Drag indicator
            if UIDevice.current.userInterfaceIdiom == .pad {
                Capsule()
                    .fill(Color.gray.opacity(isDragging ? 0.6 : 0.4))
                    .frame(width: isDragging ? 50 : 40, height: 5)
                    .padding(.top, AppSpacing.sm)
                    .animation(.spring(response: 0.3), value: isDragging)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40) // Touch area for dragging
        .contentShape(Rectangle()) // Make entire area tappable
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isDragging = true
                    // Only track downward swipes (don't move the view)
                    if value.translation.height > 0 {
                        dragAmount = value.translation.height
                    }
                }
                .onEnded { value in
                    isDragging = false
                    let threshold: CGFloat = 150 // Swipe down 150pt to dismiss

                    if value.translation.height > threshold {
                        // Provide haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()

                        // Dismiss immediately with built-in animation
                        onDismiss()
                    }

                    // Reset drag amount
                    dragAmount = 0
                }
        )
    }
}
