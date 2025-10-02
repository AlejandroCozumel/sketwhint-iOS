//
//  SketchWinkApp.swift
//  SketchWink
//
//  Created by alejandro on 18/09/25.
//

import SwiftUI
import SwiftData

@main
struct SketchWinkApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            // Use AppCoordinator for authentication flow
            AppCoordinator()
                .withAppLifecycleManagement()  // Add lifecycle management for family profiles
                .preferredColorScheme(.light)  // Force light mode - dark mode not currently supported
                .onAppear {
                    // Configure app on launch
                    configureApp()
                    // Setup global keyboard dismissal
                    setupGlobalKeyboardDismissal()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func configureApp() {
        // Configure logging
        if AppConfig.Debug.enableLogging {
            print("🚀 SketchWink app launched - Version \(AppConfig.appVersion)")
            print("📱 Environment: \(AppConfig.environmentName)")
            print("🔗 API Base URL: \(AppConfig.API.baseURL)")
        }
    }

    /// Setup global keyboard dismissal for the entire app
    private func setupGlobalKeyboardDismissal() {
        // 1. Add tap gesture to window to dismiss keyboard globally
        DispatchQueue.main.async {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }) else {
                return
            }

            let tapGesture = UITapGestureRecognizer(target: window, action: #selector(UIView.endEditing))
            tapGesture.cancelsTouchesInView = false  // Don't block other touch events
            tapGesture.requiresExclusiveTouchType = false
            window.addGestureRecognizer(tapGesture)

            if AppConfig.Debug.enableLogging {
                print("⌨️ Global keyboard dismissal enabled (tap)")
            }
        }

        // 2. Configure global scroll-to-dismiss for all ScrollViews (iOS 16+)
        if #available(iOS 16.0, *) {
            UIScrollView.appearance().keyboardDismissMode = .interactive

            if AppConfig.Debug.enableLogging {
                print("⌨️ Global keyboard dismissal enabled (scroll)")
            }
        }
    }
}
