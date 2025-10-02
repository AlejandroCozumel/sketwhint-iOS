import SwiftUI

// MARK: - Keyboard Dismiss Extension (iOS 18+ Compatible)
extension View {
    /// Dismisses keyboard when tapping outside text fields (iOS 18+ compatible)
    /// Uses simultaneousGesture to avoid interfering with other interactive elements
    func dismissKeyboardOnTap() -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                UIApplication.shared.hideKeyboard()
            }
        )
    }

    /// Applies keyboard dismiss on scroll (iOS 16+)
    /// Use this on ScrollView, List, or Form
    func dismissKeyboardOnScroll() -> some View {
        if #available(iOS 16.0, *) {
            return AnyView(self.scrollDismissesKeyboard(.interactively))
        } else {
            return AnyView(self)
        }
    }
}

// MARK: - UIApplication Extension for Keyboard Dismissal
extension UIApplication {
    func hideKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
