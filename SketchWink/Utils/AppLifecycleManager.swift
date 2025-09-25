import SwiftUI
import Combine

/// Manages app lifecycle events for security and family profile management
/// Automatically clears profile selection when app goes to background for enhanced security
class AppLifecycleManager: ObservableObject {
    static let shared = AppLifecycleManager()
    private init() {}
    
    @Published var isAppInBackground = false
    private var cancellables = Set<AnyCancellable>()
    
    /// Start monitoring app lifecycle events
    func startMonitoring() {
        #if DEBUG
        print("🔄 AppLifecycleManager: Starting app lifecycle monitoring")
        #endif
        
        // Monitor app state changes
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppWillResignActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleAppWillEnterForeground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppDidBecomeActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.handleAppWillTerminate()
            }
            .store(in: &cancellables)
    }
    
    /// Stop monitoring app lifecycle events
    func stopMonitoring() {
        #if DEBUG
        print("🔄 AppLifecycleManager: Stopping app lifecycle monitoring")
        #endif
        
        cancellables.removeAll()
    }
    
    // MARK: - App Lifecycle Handlers
    
    private func handleAppWillResignActive() {
        #if DEBUG
        print("📱 App will resign active")
        #endif
        
        // App is about to lose focus (incoming call, notification center, etc.)
        // Keep profile selection for quick return
    }
    
    private func handleAppDidEnterBackground() {
        #if DEBUG
        print("📱 App did enter background")
        #endif
        
        DispatchQueue.main.async {
            self.isAppInBackground = true
        }
        
        // Profile selection is preserved - users control when they switch profiles
    }
    
    private func handleAppWillEnterForeground() {
        #if DEBUG
        print("📱 App will enter foreground")
        #endif
        
        DispatchQueue.main.async {
            self.isAppInBackground = false
        }
        
        // Profile selection is preserved - user continues with their selected profile
    }
    
    private func handleAppDidBecomeActive() {
        #if DEBUG
        print("📱 App did become active")
        #endif
        
        // App is now active and responding to user interaction
    }
    
    private func handleAppWillTerminate() {
        #if DEBUG
        print("📱 App will terminate")
        #endif
        
        // Profile selection is preserved across app launches - users control switching
    }
    
    // MARK: - Security Methods
    
    /// Clear profile selection for security purposes
    /// Called when app goes to background or terminates
    private func clearProfileSelectionForSecurity() {
        #if DEBUG
        print("🔒 Clearing profile selection for security")
        #endif
        
        // Clear from ProfileService (clears Keychain and resets state)
        ProfileService.shared.clearSelectedProfile()
        
        #if DEBUG
        print("✅ Profile selection cleared from Keychain and ProfileService")
        #endif
    }
    
    /// Force clear profile selection (for logout or security needs)
    func forceProfileSelectionClear() {
        #if DEBUG
        print("🔒 Force clearing profile selection")
        #endif
        
        clearProfileSelectionForSecurity()
    }
    
    // MARK: - Helper Methods
    
    /// Check if the app should require profile reselection
    var shouldRequireProfileReselection: Bool {
        // If no profile is selected, reselection is required
        return !ProfileService.shared.hasSelectedProfile
    }
    
    /// Check if profile selection was cleared due to background/termination
    var wasProfileClearedByLifecycle: Bool {
        // If user is authenticated but no profile selected, likely cleared by lifecycle
        return AuthService.shared.isAuthenticated && !ProfileService.shared.hasSelectedProfile
    }
}

// MARK: - SwiftUI Integration

/// View modifier to automatically handle app lifecycle management
struct AppLifecycleModifier: ViewModifier {
    @StateObject private var lifecycleManager = AppLifecycleManager.shared
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                lifecycleManager.startMonitoring()
            }
            .onDisappear {
                lifecycleManager.stopMonitoring()
            }
            .environmentObject(lifecycleManager)
    }
}

extension View {
    /// Apply app lifecycle management to this view
    func withAppLifecycleManagement() -> some View {
        modifier(AppLifecycleModifier())
    }
}