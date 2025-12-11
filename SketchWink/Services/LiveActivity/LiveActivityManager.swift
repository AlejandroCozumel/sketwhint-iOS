import ActivityKit
import Foundation

@available(iOS 16.1, *)
class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private init() {}
    
    // MARK: - Activity Management
    
    func startGenerationActivity(
        generationId: String,
        storyTitle: String,
        type: GenerationAttributes.GenerationType,
        thumbnailUrl: String?
    ) {
        // Ensure Live Activities are supported and enabled
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("🚫 LiveActivityManager: Activities are not enabled")
            return
        }
        
        // 1. Cleanup Key: End ANY existing activities before starting a new one.
        // This ensures the "New one is always on top" and we don't pile up stale widgets.
        Task {
            for activity in Activity<GenerationAttributes>.activities {
                print("🧹 LiveActivityManager: Cleaning up stale activity \(activity.id)")
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            
            // 2. Start the new Activity
            let attributes = GenerationAttributes(
                storyTitle: storyTitle,
                generationId: generationId,
                type: type,
                thumbnailUrl: thumbnailUrl.flatMap { URL(string: $0) }
            )
            
            let initialContentState = GenerationAttributes.ContentState(
                progress: 0.0,
                currentStep: type == .book ? NSLocalizedString("live_activity.status.generating_book", comment: "") : NSLocalizedString("live_activity.status.generating_bedtime", comment: ""),
                status: .generating
            )
            
            do {
                let activity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: initialContentState, staleDate: nil),
                    pushType: nil // We are using local updates via receiving SSE in the app
                )
                print("✅ LiveActivityManager: Started activity \(activity.id) for generation \(generationId)")
            } catch {
                print("❌ LiveActivityManager: Failed to start activity: \(error)")
            }
        }
    }
    
    func updateGenerationProgress(
        generationId: String,
        progress: Double,
        message: String?,
        type: GenerationAttributes.GenerationType = .book
    ) {
        Task {
            // Check if activity exists
            if let activity = Activity<GenerationAttributes>.activities.first(where: { $0.attributes.generationId == generationId }) {
                // Update existing
                let updatedContentState = GenerationAttributes.ContentState(
                    progress: progress / 100.0, // Convert 0-100 to 0.0-1.0
                    currentStep: message ?? NSLocalizedString("live_activity.status.processing", comment: ""),
                    status: .generating
                )
                
                await activity.update(
                    ActivityContent(state: updatedContentState, staleDate: nil)
                )
                print("🔄 LiveActivityManager: Updated activity for \(generationId) - \(Int(progress))%")
            } else {
                // Start new (Fallback for books or app restart)
                print("⚠️ LiveActivityManager: Activity not found for \(generationId). Starting new one.")
                let title = type == .book ? NSLocalizedString("live_activity.type.book", comment: "") : NSLocalizedString("live_activity.type.bedtime", comment: "")
                startGenerationActivity(
                    generationId: generationId,
                    storyTitle: title,
                    type: type,
                    thumbnailUrl: nil
                )
            }
        }
    }
    
    func endGenerationActivity(
        generationId: String,
        status: GenerationAttributes.ContentState.GenerationStatus
    ) {
        Task {
            guard let activity = Activity<GenerationAttributes>.activities.first(where: { $0.attributes.generationId == generationId }) else {
                return
            }
            
            let finalStatusText = status == .completed ? NSLocalizedString("live_activity.status.ready", comment: "") : NSLocalizedString("live_activity.status.failed", comment: "")
            
            let finalContentState = GenerationAttributes.ContentState(
                progress: 1.0,
                currentStep: finalStatusText,
                status: status
            )
            
            // End immediately, or with a slight delay/dismissal policy
            await activity.end(
                ActivityContent(state: finalContentState, staleDate: nil),
                dismissalPolicy: .default // Keep it on lock screen for a bit so user sees it finished
            )
            print("🏁 LiveActivityManager: Ended activity for \(generationId) with status \(status)")
        }
    }
    
    // Helper to stop all activities (e.g. on logout)
    func stopAllActivities() {
        Task {
            for activity in Activity<GenerationAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
    
    // Req 1: Only dismiss on tap if it's actually finished.
    // If it's still generating, we want to keep it on the island while opening the app.
    func dismissIfCompleted(generationId: String) {
        Task {
            guard let activity = Activity<GenerationAttributes>.activities.first(where: { $0.attributes.generationId == generationId }) else { return }
            
            // Check the *current* state of the activity content
            if activity.content.state.status == .completed || activity.content.state.status == .failed {
                print("👋 LiveActivityManager: Dismissing COMPLETED activity \(generationId) on user tap")
                await activity.end(nil, dismissalPolicy: .immediate)
            } else {
                print("👀 LiveActivityManager: User tapped GENERATING activity \(generationId). Keeping it alive.")
            }
        }
    }
    
    // Req 2: If we open the app and find lingering "Completed" widgets, kill them.
    // Returns true if a completed activity was found and dismissed (so we can show a toast)
    func dismissAllCompletedActivities() async -> Bool {
        var dismissedSomething = false
        for activity in Activity<GenerationAttributes>.activities {
            if activity.content.state.status == .completed {
                print("🧹 LiveActivityManager: Cleaning up lingering completed activity \(activity.id)")
                await activity.end(nil, dismissalPolicy: .immediate)
                dismissedSomething = true
            } else if activity.content.state.status == .failed {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        return dismissedSomething
    }
}
