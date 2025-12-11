import ActivityKit
import Foundation

public struct GenerationAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic state that changes during the activity
        public var progress: Double // 0.0 to 1.0
        public var currentStep: String // e.g., "Writing Chapter 1", "Illustrating..."
        public var status: GenerationStatus
        
        public init(progress: Double, currentStep: String, status: GenerationStatus) {
            self.progress = progress
            self.currentStep = currentStep
            self.status = status
        }
        
        public enum GenerationStatus: String, Codable, Hashable {
            case generating
            case completed
            case failed
        }
    }

    // Static data that doesn't change
    public var storyTitle: String
    public var generationId: String
    public var type: GenerationType
    public var thumbnailUrl: URL?
    
    public init(storyTitle: String, generationId: String, type: GenerationType, thumbnailUrl: URL? = nil) {
        self.storyTitle = storyTitle
        self.generationId = generationId
        self.type = type
        self.thumbnailUrl = thumbnailUrl
    }
    
    public enum GenerationType: String, Codable, Hashable {
        case book
        case bedtimeStory
    }
}
