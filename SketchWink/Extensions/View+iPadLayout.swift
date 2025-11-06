//
//  View+iPadLayout.swift
//  SketchWink
//
//  iPad-specific layout adjustments for better content presentation
//

import SwiftUI

extension View {
    /// Adds horizontal padding on iPad for better content layout
    /// On iPhone, uses standard padding. On iPad, adds extra horizontal space.
    func iPadContentPadding() -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return AnyView(
                self.padding(.horizontal, 60) // 60pt padding on each side for iPad
            )
        } else {
            return AnyView(self)
        }
    }

    /// Adds maximum width constraint for content on iPad
    /// Keeps content centered and readable on large screens
    func iPadMaxWidth() -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return AnyView(
                self
                    .frame(maxWidth: 900) // Max width for content
                    .frame(maxWidth: .infinity) // Center it
            )
        } else {
            return AnyView(self)
        }
    }

    /// Combined: padding + max width for optimal iPad layout
    func iPadOptimalLayout() -> some View {
        self
            .iPadContentPadding()
            .iPadMaxWidth()
    }
}
