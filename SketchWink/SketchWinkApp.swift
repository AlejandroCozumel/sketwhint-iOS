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
}
