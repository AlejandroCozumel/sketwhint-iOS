import Foundation
import Combine

// MARK: - Generation Progress SSE Service
class GenerationProgressSSEService: ObservableObject {
    static let shared = GenerationProgressSSEService()

    private var eventSource: EventSourceService?
    private var cancellables = Set<AnyCancellable>()
    private var lastAuthToken: String?
    private var isReconnecting = false
    private var reconnectAttempt = 0
    private let maxReconnectAttempts = 5
    private var lastMessageAt = Date()
    private var watchdogTimer: Timer?
    private var hasOpened = false

    // Current generation progress state
    @Published var currentProgress: GenerationProgress?
    @Published var isConnected = false
    @Published var connectionError: Error?

    // Callbacks
    var onProgressUpdate: ((GenerationProgress) -> Void)?
    var onGenerationComplete: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    private init() {}

    // Current generation ID we're tracking
    var trackingGenerationId: String?

    // MARK: - Connection Management
    func connectToUserProgress(authToken: String, trackingGenerationId: String? = nil) {
        // Persist last auth token for auto-reconnects
        self.lastAuthToken = authToken

        // Update tracking ID only if a non-nil, non-empty value is provided
        if let trackingGenerationId = trackingGenerationId, !trackingGenerationId.isEmpty {
            self.trackingGenerationId = trackingGenerationId
        }

        // If already connected, keep the existing connection (and current tracking ID if nil was provided)
        if isConnected && eventSource != nil {
            #if DEBUG
            let tracked = self.trackingGenerationId ?? "nil"
            print("🔗 GenerationProgressSSE: Already connected. Keeping connection. Current tracking ID: \(tracked)")
            print("🔗 GenerationProgressSSE: Note: This should not happen with fresh connection per generation approach")
            #endif
            return
        }

        // Disconnect any existing connection object but keep current progress/state
        if eventSource != nil {
            eventSource?.disconnect()
            eventSource = nil
        }

        // Build SSE endpoint URL using user-progress endpoint
        let sseURLString = "\(AppConfig.API.baseURL)\(AppConfig.API.Endpoints.sseUserProgress)"

        guard let sseURL = URL(string: sseURLString) else {
            let error = EventSourceError.invalidURL
            self.connectionError = error
            self.onError?(error)
            return
        }

        #if DEBUG
        print("🔗 GenerationProgressSSE: Connecting to user progress stream: \(sseURL.absoluteString)")
        if let trackingId = trackingGenerationId {
            print("🔗 GenerationProgressSSE: Tracking generation: \(trackingId)")
        }
        #endif

        // Create EventSource with auth headers
        let headers = [
            "Authorization": "Bearer \(authToken)"
        ]

        eventSource = EventSourceService(url: sseURL, headers: headers)

        // Set up event handlers
        setupEventHandlers()

        // Connect
        eventSource?.connect()
    }

    func disconnect() {
        #if DEBUG
        print("🔗 GenerationProgressSSE: Disconnecting SSE connection")
        print("🔗 GenerationProgressSSE: Current tracking ID: \(trackingGenerationId ?? "nil")")
        print("🔗 GenerationProgressSSE: Connection status before disconnect: \(isConnected)")
        #endif

        eventSource?.disconnect()
        eventSource = nil

        // Reset reconnect state
        isReconnecting = false
        reconnectAttempt = 0
        hasOpened = false
        stopWatchdog()

        DispatchQueue.main.async {
            self.isConnected = false
            // Clear current progress when disconnecting
            self.currentProgress = nil
        }
        
        #if DEBUG
        print("🔗 GenerationProgressSSE: Disconnection complete")
        #endif
    }

    // Method to start tracking a new generation without reconnecting
    func startTrackingGeneration(_ generationId: String) {
        #if DEBUG
        print("🔗 GenerationProgressSSE: Now tracking generation: \(generationId)")
        print("🔗 GenerationProgressSSE: Connection status: isConnected=\(isConnected), eventSource=\(eventSource != nil)")
        #endif

        self.trackingGenerationId = generationId

        // Reset current progress for new generation (start at 0% queued to avoid UI flash)
        DispatchQueue.main.async {
            self.currentProgress = GenerationProgress(
                generationId: generationId,
                status: .queued,
                progress: 0,
                imageCount: 0,
                error: nil
            )
        }

        // Add a simple health check to ensure we're still connected
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            #if DEBUG
            print("🔗 GenerationProgressSSE: Health check - isConnected: \(self.isConnected), tracking: \(self.trackingGenerationId ?? "nil")")
            #endif

            if !self.isConnected {
                #if DEBUG
                print("🔗 GenerationProgressSSE: ⚠️ Connection lost during tracking!")
                #endif
            }
        }
    }

    // MARK: - Event Handling
    private func setupEventHandlers() {
        guard let eventSource = eventSource else { return }

        // Connection opened
        eventSource.onOpen = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isConnected = true
                self.connectionError = nil
                self.lastMessageAt = Date()
                self.hasOpened = true
                self.startWatchdog()
            }

            #if DEBUG
            print("🔗 GenerationProgressSSE: Connected successfully")
            #endif
        }

        // Message received
        eventSource.onMessage = { [weak self] event in
            self?.handleSSEMessage(event)
        }

        // Error occurred
        eventSource.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.connectionError = error
            }
            self?.onError?(error)

            #if DEBUG
            print("🔗 GenerationProgressSSE: Error - \(error.localizedDescription)")
            #endif

            // Attempt to reconnect if we are still tracking an active generation
            self?.scheduleReconnect()
        }

        // Subscribe to connection state changes
        eventSource.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                guard let self = self else { return }
                self.isConnected = isConnected
                if isConnected == false {
                    // Only schedule reconnects after a successful open
                    guard self.hasOpened else { return }
                    self.scheduleReconnect()
                } else {
                    self.reconnectAttempt = 0
                    self.isReconnecting = false
                }
            }
            .store(in: &cancellables)

        eventSource.$connectionError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.connectionError = error
            }
            .store(in: &cancellables)
    }

    private func handleSSEMessage(_ event: EventSourceEvent) {
        #if DEBUG
        print("🔗 GenerationProgressSSE: 📨 Received SSE message:")
        print("🔗 GenerationProgressSSE: 📨   Event type: '\(event.event ?? "nil")'")
        print("🔗 GenerationProgressSSE: 📨   Event ID: '\(event.id ?? "nil")'")
        print("🔗 GenerationProgressSSE: 📨   Data: '\(event.data)'")
        print("🔗 GenerationProgressSSE: 📨   Data length: \(event.data.count) characters")
        print("🔗 GenerationProgressSSE: 📨   Data is empty: \(event.data.isEmpty)")
        #endif

        // Skip empty messages
        if event.data.isEmpty {
            #if DEBUG
            print("🔗 GenerationProgressSSE: ⚠️ Skipping empty message")
            #endif
            return
        }

        // Parse JSON data
        guard let data = event.data.data(using: .utf8) else {
            #if DEBUG
            print("🔗 GenerationProgressSSE: ❌ Failed to convert data to UTF8")
            #endif
            return
        }

        #if DEBUG
        print("🔗 GenerationProgressSSE: 🔄 Converting to JSON...")
        #endif

        do {
            let progressData = try JSONDecoder().decode(GenerationProgressData.self, from: data)

            #if DEBUG
            print("🔗 GenerationProgressSSE: ✅ Successfully decoded JSON message")
            print("🔗 GenerationProgressSSE: ✅ Message type: '\(progressData.type)'")
            if let genId = progressData.generationId {
                print("🔗 GenerationProgressSSE: ✅ Generation ID: '\(genId)'")
            }
            if let status = progressData.status {
                print("🔗 GenerationProgressSSE: ✅ Status: '\(status)'")
            }
            if let progress = progressData.progress {
                print("🔗 GenerationProgressSSE: ✅ Progress: \(progress)%")
            }
            print("🔗 GenerationProgressSSE: ✅ Current connection status: \(self.isConnected)")
            #endif

            // Refresh heartbeat timestamp for any valid decoded message
            self.lastMessageAt = Date()

            // Handle different event types
            switch progressData.type {
            case "connected":
                #if DEBUG
                print("🔗 GenerationProgressSSE: Connected to progress stream")
                #endif

            case "progress":
                // Log ALL progress messages we receive
                // Accept messages even if server omits generationId by assuming the currently tracked one
                let incomingIdRaw = progressData.generationId?.trimmingCharacters(in: .whitespacesAndNewlines)
                let hasIncomingId = !(incomingIdRaw?.isEmpty ?? true)
                let effectiveGenerationId = hasIncomingId ? (incomingIdRaw ?? "") : (self.trackingGenerationId ?? "")

                #if DEBUG
                print("🔗 GenerationProgressSSE: 🎯 RECEIVED PROGRESS MESSAGE!")
                print("🔗 GenerationProgressSSE: 🎯   Incoming Generation ID: '\(incomingIdRaw ?? "nil")'")
                print("🔗 GenerationProgressSSE: 🎯   Effective Generation ID: '\(effectiveGenerationId)'")
                print("🔗 GenerationProgressSSE: 🎯   Status: '\(progressData.status ?? "nil")'")
                print("🔗 GenerationProgressSSE: 🎯   Progress: \(progressData.progress ?? -1)%")
                print("🔗 GenerationProgressSSE: 🎯   Currently tracking: '\(self.trackingGenerationId ?? "none")'")
                print("🔗 GenerationProgressSSE: 🎯   User ID: '\(progressData.userId ?? "nil")'")
                print("🔗 GenerationProgressSSE: 🎯   Replicate Status: '\(progressData.replicateStatus ?? "nil")'")
                print("🔗 GenerationProgressSSE: 🎯   Has Output: \(progressData.hasOutput ?? false)")
                print("🔗 GenerationProgressSSE: 🎯   Image Count: \(progressData.imageCount ?? 0)")
                #endif

                // Only process updates for the generation we're tracking (if specified)
                if let trackingId = self.trackingGenerationId, !trackingId.isEmpty {
                    // If the server omitted the ID, treat it as matching the tracking one
                    if hasIncomingId && trackingId != effectiveGenerationId {
                        #if DEBUG
                        print("🔗 GenerationProgressSSE: ⚠️ Ignoring progress for generation '\(effectiveGenerationId)', tracking '\(trackingId)'")
                        #endif
                        return
                    } else {
                        #if DEBUG
                        let assumed = hasIncomingId ? "" : " (assumed from tracking ID)"
                        print("🔗 GenerationProgressSSE: ✅ Processing progress for generation \(effectiveGenerationId)\(assumed)")
                        print("🔗 GenerationProgressSSE: ✅ Status update: \(progressData.status ?? "nil")")
                        print("🔗 GenerationProgressSSE: ✅ Progress update: \(progressData.progress ?? -1)%")
                        #endif
                    }
                } else {
                    #if DEBUG
                    print("🔗 GenerationProgressSSE: ✅ Processing progress (no specific tracking ID set)")
                    #endif
                }

                let progress = GenerationProgress(
                    generationId: effectiveGenerationId,
                    status: GenerationStatus(rawValue: progressData.status ?? "queued") ?? .queued,
                    progress: progressData.progress ?? 0,
                    imageCount: progressData.imageCount ?? 0,
                    error: progressData.error
                )

                DispatchQueue.main.async {
                    self.currentProgress = progress
                }

                self.onProgressUpdate?(progress)

                // Check if generation completed
                if progress.status == .completed {
                    // Clear any reconnect attempts on completion
                    self.reconnectAttempt = 0
                    self.isReconnecting = false
                    self.stopWatchdog()
                    self.onGenerationComplete?(progress.generationId)
                    // Don't disconnect - user might start another generation
                } else if progress.status == .failed {
                    // Clear any reconnect attempts on failure
                    self.reconnectAttempt = 0
                    self.isReconnecting = false
                    self.stopWatchdog()
                    let error = GenerationProgressError.generationFailed(progress.error ?? "Generation failed")
                    self.onError?(error)
                    // Don't disconnect - user might retry
                }

            case "ping":
                // Keep-alive ping, no action needed
                #if DEBUG
                print("🔗 GenerationProgressSSE: Received keep-alive ping")
                #endif

            default:
                #if DEBUG
                print("🔗 GenerationProgressSSE: ❓ Unknown event type: '\(progressData.type)'")
                print("🔗 GenerationProgressSSE: ❓ Full message data: \(progressData)")
                print("🔗 GenerationProgressSSE: ❓ Raw message: '\(event.data)'")

                // Check if this might be a progress message with a different type
                if let generationId = progressData.generationId, !generationId.isEmpty {
                    print("🔗 GenerationProgressSSE: ❓ This unknown message has a generation ID: \(generationId)")
                    print("🔗 GenerationProgressSSE: ❓ Status: \(progressData.status ?? "nil")")
                    print("🔗 GenerationProgressSSE: ❓ Progress: \(progressData.progress ?? -1)")
                }
                #endif
            }

        } catch {
            #if DEBUG
            print("🔗 GenerationProgressSSE: Failed to decode progress data: \(error)")
            print("🔗 GenerationProgressSSE: Raw data was: \(event.data)")
            #endif
        }
    }
    // Inactivity watchdog — observe stalls but do NOT force reconnects (to avoid breaking long gaps like 30%→60%)
    private func startWatchdog() {
        stopWatchdog()
        // Check every 10 seconds; just log if no messages for >60 seconds. Reconnects are handled by isConnected/onError.
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // If finished, stop watching
            if let status = self.currentProgress?.status, status == .completed || status == .failed {
                self.stopWatchdog()
                return
            }
            // Only care when we are tracking something
            guard let trackingId = self.trackingGenerationId, !trackingId.isEmpty else { return }
            let elapsed = Date().timeIntervalSince(self.lastMessageAt)
            if elapsed > 60.0 {
                #if DEBUG
                print("🔗 GenerationProgressSSE: ⏳ No SSE messages for \(Int(elapsed))s while tracking \(trackingId). Not forcing reconnect (stream may be idle between stages).")
                #endif
                // No forced reconnect here. If the socket actually drops, eventSource.$isConnected or onError triggers scheduleReconnect().
            }
        }
    }

    private func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }

    // Auto-reconnect scheduler to keep SSE alive during active generation
    private func scheduleReconnect(force: Bool = false) {
        // Only attempt when not already reconnecting and generation not finished
        let finished = (self.currentProgress?.status == .completed || self.currentProgress?.status == .failed)
        guard !self.isReconnecting, !finished else { return }
        guard let token = self.lastAuthToken else { return }
        guard let trackingId = self.trackingGenerationId, !trackingId.isEmpty else { return }
        guard self.reconnectAttempt < self.maxReconnectAttempts else {
            #if DEBUG
            print("🔗 GenerationProgressSSE: ❌ Max reconnect attempts reached. Giving up.")
            #endif
            return
        }

        // If not forcing, only reconnect when actually disconnected
        if !force && self.isConnected {
            return
        }

        self.isReconnecting = true
        let delay = min(8.0, pow(2.0, Double(self.reconnectAttempt)))
        #if DEBUG
        let mode = force ? "forced" : "normal"
        print("🔗 GenerationProgressSSE: 🔁 Scheduling \(mode) reconnect attempt \(self.reconnectAttempt + 1) in \(delay)s (tracking \(trackingId))")
        #endif

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            // If finished in the meantime, don't reconnect
            let finishedNow = (self.currentProgress?.status == .completed || self.currentProgress?.status == .failed)
            if finishedNow {
                self.isReconnecting = false
                self.reconnectAttempt = 0
                return
            }
            // If not forcing and we are connected again, skip this attempt
            if !force && self.isConnected {
                self.isReconnecting = false
                self.reconnectAttempt = 0
                return
            }

            // Bump attempt count
            self.reconnectAttempt += 1

            // Force clean state and reconnect
            self.eventSource?.disconnect()
            self.eventSource = nil
            self.connectToUserProgress(authToken: token, trackingGenerationId: trackingId)

            // Allow subsequent retries if still not connected
            self.isReconnecting = false
        }
    }
}

// MARK: - Generation Progress Models
struct GenerationProgressData: Codable {
    let type: String
    let generationId: String?
    let userId: String?
    let status: String?
    let progress: Int?
    let replicateStatus: String?
    let hasOutput: Bool?
    let imageCount: Int?
    let error: String?
    let timestamp: String?
}

struct GenerationProgress {
    let generationId: String
    let status: GenerationStatus
    let progress: Int // 0-100
    let imageCount: Int
    let error: String?

    var progressPercentage: Double {
        return Double(progress) / 100.0
    }
}

enum GenerationStatus: String, CaseIterable {
    case queued = "queued"
    case starting = "starting"
    case processing = "processing"
    case completing = "completing"
    case completed = "completed"
    case failed = "failed"

    var displayMessage: String {
        switch self {
        case .queued:
            return "Getting Ready for Magic!"
        case .starting:
            return "Waking Up the Art Wizards!"
        case .processing:
            return "Creating Your Masterpiece!"
        case .completing:
            return "Adding Magical Sparkles!"
        case .completed:
            return "Your Art is Ready!"
        case .failed:
            return "Oops! Let's Try Again!"
        }
    }

    // Magical alternative messages for variety
    var alternativeDisplayMessage: String {
        switch self {
        case .queued:
            return ["Preparing the Magic Studio!", "Gathering Rainbow Colors!", "Setting Up the Art Workshop!"].randomElement() ?? displayMessage
        case .starting:
            return ["Summoning Creative Spirits!", "Opening the Magic Art Book!", "Lighting the Creativity Candles!"].randomElement() ?? displayMessage
        case .processing:
            return ["Painting with Stardust!", "Mixing Rainbow Magic!", "Drawing with Unicorn Brushes!"].randomElement() ?? displayMessage
        case .completing:
            return ["Sprinkling Fairy Dust!", "Adding Golden Touches!", "Polishing with Magic Cloth!"].randomElement() ?? displayMessage
        case .completed:
            return ["Magic Complete!", "Masterpiece Finished!", "Art Adventure Success!"].randomElement() ?? displayMessage
        case .failed:
            return ["Magic Needs a Restart!", "Time for a New Spell!", "Let's Try Different Magic!"].randomElement() ?? displayMessage
        }
    }

    var icon: String {
        switch self {
        case .queued:
            return "✨"
        case .starting:
            return "🧙‍♂️"
        case .processing:
            return "🎨"
        case .completing:
            return "⭐"
        case .completed:
            return "🎉"
        case .failed:
            return "😔"
        }
    }

    var color: String {
        switch self {
        case .queued:
            return "#FF9800" // Orange
        case .starting:
            return "#2196F3" // Blue
        case .processing:
            return "#4CAF50" // Green
        case .completing:
            return "#9C27B0" // Purple
        case .completed:
            return "#4CAF50" // Green
        case .failed:
            return "#F44336" // Red
        }
    }
}

// MARK: - Generation Progress Errors
enum GenerationProgressError: LocalizedError {
    case connectionFailed
    case generationFailed(String)
    case timeout
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to connect to progress stream"
        case .generationFailed(let message):
            return "Generation failed: \(message)"
        case .timeout:
            return "Generation timed out"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}