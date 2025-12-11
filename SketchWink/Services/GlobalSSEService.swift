import Foundation
import Combine
import UIKit
import AVFoundation

final class GlobalSSEService: ObservableObject {
    static let shared = GlobalSSEService()
    
    // MARK: - Properties
    
    // Connection State
    @Published var isConnected = false
    @Published var connectionError: Error?
    
    @Published var lastEventAt: Date?
    
    // User Context
    private var authToken: String?
    private var currentProfileId: String?
    
    // Service
    private var eventSource: EventSourceService?
    private var cancellables = Set<AnyCancellable>()
    
    // Reconnection Logic
    private var isReconnecting = false
    private var reconnectAttempt = 0
    private let maxReconnectAttempts = 5
    private var isAppInBackground = false
    private var hasOpened = false // Track if we ever successfully connected
    
    // Listeners
    private var observers: [String: [(EventSourceEvent) -> Void]] = [:]
    private var observersLock = NSLock()
    
    // Background Task Support
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var audioPlayer: AVAudioPlayer?
    
    private init() {
        print("🌍 GlobalSSEService: Initializing shared instance")
        setupAppLifecycleObservers()
        prepareSilentAudio()
    }
    
    // MARK: - Silent Audio Setup
    
    private func prepareSilentAudio() {
        // Generate a 1-second silent WAV file in memory
        // RIFF header (12) + fmt chunk (24) + data chunk (8) + 1 sec of silence (44100 * 2 bytes)
        // Total ~88KB. Minimal overhead.
        
        let sampleRate: Int32 = 44100
        let duration: Int32 = 5 // 5 Seconds loop
        let dataSize = Int32(sampleRate * duration * 2) // 16-bit mono
        let fileSize = 36 + dataSize
        
        var wavData = Data()
        
        // RIFF chunk
        wavData.append(contentsOf: "RIFF".utf8)
        wavData.append(withUnsafeBytes(of: fileSize) { Data($0) })
        wavData.append(contentsOf: "WAVE".utf8)
        
        // fmt chunk
        wavData.append(contentsOf: "fmt ".utf8)
        wavData.append(withUnsafeBytes(of: Int32(16)) { Data($0) }) // chunk size
        wavData.append(withUnsafeBytes(of: Int16(1)) { Data($0) }) // audio format (PCM)
        wavData.append(withUnsafeBytes(of: Int16(1)) { Data($0) }) // num channels (1)
        wavData.append(withUnsafeBytes(of: sampleRate) { Data($0) }) // sample rate
        wavData.append(withUnsafeBytes(of: sampleRate * 2) { Data($0) }) // byte rate
        wavData.append(withUnsafeBytes(of: Int16(2)) { Data($0) }) // block align
        wavData.append(withUnsafeBytes(of: Int16(16)) { Data($0) }) // bits per sample
        
        // data chunk
        wavData.append(contentsOf: "data".utf8)
        wavData.append(withUnsafeBytes(of: dataSize) { Data($0) })
        
        // Silence (zeros)
        wavData.append(Data(count: Int(dataSize)))
        
        do {
            audioPlayer = try AVAudioPlayer(data: wavData)
            audioPlayer?.numberOfLoops = -1 // Infinite loop
            audioPlayer?.volume = 0.0 // Silent
            audioPlayer?.prepareToPlay()
            #if DEBUG
            print("🌍 GlobalSSEService: 🔇 Silent audio player prepared")
            #endif
        } catch {
            print("🌍 GlobalSSEService: ❌ Failed to create silent audio player: \(error)")
        }
    }
    
    private func startSilentAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer?.play()
            #if DEBUG
            print("🌍 GlobalSSEService: 🔇 Silent audio started (background keep-alive)")
            #endif
        } catch {
            print("🌍 GlobalSSEService: ❌ Failed to start silent audio: \(error)")
        }
    }
    
    private func stopSilentAudio() {
        audioPlayer?.stop()
        #if DEBUG
        print("🌍 GlobalSSEService: 🔇 Silent audio stopped")
        #endif
        // We don't deactivate the session immediately as it might cut off actual audio if playing
    }
    
    // MARK: - Public API
    
    /// Connect to the global SSE stream with the given auth token
    func connect(authToken: String) {
        self.authToken = authToken
        
        // If already connected, do nothing
        if isConnected && eventSource != nil {
            #if DEBUG
            print("🌍 GlobalSSEService: Already connected. Keeping connection.")
            #endif
            return
        }
        
        establishConnection()
    }
    
    /// Observe a specific event type
    func observe(event: String, handler: @escaping (EventSourceEvent) -> Void) {
        observersLock.lock()
        defer { observersLock.unlock() }
        
        if observers[event] == nil {
            observers[event] = []
        }
        observers[event]?.append(handler)
        
        #if DEBUG
        print("🌍 GlobalSSEService: Registered observer for event '\(event)'")
        #endif
    }
    
    /// Disconnect manually (e.g. logout)
    /// Disconnect manually (e.g. logout)
    func disconnect() {
        // Ensure state mutation happens on Main Thread to prevent EXC_BAD_ACCESS on @Published
        DispatchQueue.main.async {
            #if DEBUG
            print("🌍 GlobalSSEService: Disconnecting...")
            #endif
            
            self.eventSource?.disconnect()
            self.eventSource = nil
            
            self.isReconnecting = false
            self.reconnectAttempt = 0
            self.hasOpened = false
            self.authToken = nil // Clear token on manual disconnect
            self.isConnected = false
        }
    }
    
    // MARK: - Internal Connection Logic
    
    private func establishConnection() {
        guard let token = authToken else {
            #if DEBUG
            print("🌍 GlobalSSEService: ❌ Cannot connect without auth token")
            #endif
            return
        }
        
        // Build SSE endpoint URL
        let sseURLString = "\(AppConfig.API.baseURL)\(AppConfig.API.Endpoints.sseUserProgress)"
        
        guard let sseURL = URL(string: sseURLString) else {
            let error = EventSourceError.invalidURL
            DispatchQueue.main.async {
                self.connectionError = error
            }
            return
        }
        
        // Clean up existing
        eventSource?.disconnect()
        
        #if DEBUG
        print("🌍 GlobalSSEService: Connecting to \(sseURLString)")
        #endif
        
        let headers = ["Authorization": "Bearer \(token)"]
        eventSource = EventSourceService(url: sseURL, headers: headers)
        
        setupEventHandlers()
        eventSource?.connect()
    }
    
    private func setupEventHandlers() {
        guard let eventSource = eventSource else { return }
        
        // On Open
        eventSource.onOpen = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isConnected = true
                self.connectionError = nil
                self.hasOpened = true
                self.reconnectAttempt = 0
                self.isReconnecting = false
            }
            #if DEBUG
            print("🌍 GlobalSSEService: ✅ Connected successfully")
            #endif
        }
        
        // On Message
        eventSource.onMessage = { [weak self] event in
            self?.handleIncomingEvent(event)
        }
        
        // On Error
        eventSource.onError = { [weak self] error in
            self?.handleConnectionError(error)
        }
        
        // Sync published properties
        eventSource.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: \.isConnected, on: self)
            .store(in: &cancellables)
            
        eventSource.$connectionError
            .receive(on: DispatchQueue.main)
            .assign(to: \.connectionError, on: self)
            .store(in: &cancellables)
    }
    
    private func handleIncomingEvent(_ event: EventSourceEvent) {
        DispatchQueue.main.async {
            self.lastEventAt = Date()
        }
        
        #if DEBUG
        // Only log non-ping events to reduce noise
        if event.type != "ping" {
            print("🌍 GlobalSSEService: 📨 Received event type: '\(event.type ?? "nil")'")
        }
        #endif
        
        guard let type = event.type else { return }
        
        // Dynamic Island / Live Activity Integration
        if #available(iOS 16.1, *) {
            if type == "progress" {
                handleLiveActivityUpdate(event)
            }
        }
        
        // Dispatch to observers
        observersLock.lock()
        let handlers = observers[type] ?? []
        observersLock.unlock()
        
        for handler in handlers {
            handler(event)
        }
    }
    
    private func handleConnectionError(_ error: Error) {
        // Suppress errors if backgrounded
        if isAppInBackground {
            #if DEBUG
            print("🌍 GlobalSSEService: shhh... ignoring error while backgrounded")
            #endif
            return
        }
        
        #if DEBUG
        print("🌍 GlobalSSEService: ⚠️ Error: \(error.localizedDescription)")
        #endif
        
        scheduleReconnect()
    }
    
    // MARK: - Reconnection Strategy
    
    private func scheduleReconnect(force: Bool = false) {
        guard !isReconnecting else { return }
        guard authToken != nil else { return }
        
        // If connection is actually alive (and not forced), don't reconnect
        if !force && isConnected { return }
        
        // If we hit max attempts, we stop trying until next foreground or manual connect
        if reconnectAttempt >= maxReconnectAttempts {
            #if DEBUG
            print("🌍 GlobalSSEService: ❌ Max reconnect attempts reached. Giving up until next foreground/interaction.")
            #endif
            // NOTE: Dependent services (polling fallback) should handle this state via observing isConnected
            return
        }
        
        isReconnecting = true
        let delay = min(8.0, pow(2.0, Double(reconnectAttempt)))
        
        #if DEBUG
        print("🌍 GlobalSSEService: 🔁 Scheduling reconnect #\(reconnectAttempt + 1) in \(delay)s")
        #endif
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            
            // Re-check conditions
            if !force && self.isConnected {
                self.isReconnecting = false
                return
            }
            
            self.reconnectAttempt += 1
            self.establishConnection()
            self.isReconnecting = false
        }
    }
    
    // MARK: - App Lifecycle
    

    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        isAppInBackground = true
        
        // Only engage "Keep-Alive" if we actually have active generations running.
        if LiveActivityManager.shared.hasActiveActivities() {
            #if DEBUG
            print("🌍 GlobalSSEService: 📱 App backgrounded. Engaging Keep-Alive protocols for active generation.")
            #endif
            
            // 1. Start Silent Audio (Primary Keep-Alive)
            startSilentAudio()
            
            // 2. Start Background Task (Secondary/Fallback)
            backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
                #if DEBUG
                print("🌍 GlobalSSEService: ⏰ Background time expired. Disconnecting.")
                #endif
                self?.disconnect()
                self?.stopSilentAudio() 
                self?.endBackgroundTask()
            }
        } else {
            #if DEBUG
            print("🌍 GlobalSSEService: 📱 App backgrounded. No active generations. Soft disconnecting.")
            #endif
            // Soft Disconnect: Kill socket to stop pings immediately.
            eventSource?.disconnect()
            eventSource = nil
        }
    }
    
    @objc private func appDidBecomeActive() {
        isAppInBackground = false
        
        // Stop the explicit background hacks
        stopSilentAudio()
        endBackgroundTask()
        
        #if DEBUG
        print("🌍 GlobalSSEService: 📱 App foregrounded.")
        #endif
        
        guard authToken != nil else { return }
        
        if !isConnected || eventSource == nil {
            #if DEBUG
            print("🌍 GlobalSSEService: 📱 Restoring connection...")
            #endif
            reconnectAttempt = 0 // Reset attempts on manual/foreground action
            establishConnection()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // Helper to stop all background keep-alive hacks
    // AND disconnect the socket to ensure no more data usage/pings.
    private func stopBackgroundWork() {
        print("🌍 GlobalSSEService: 🛑 Smart Suspend: Stopping audio & background task.")
        stopSilentAudio()
        endBackgroundTask()
        
        // "Soft Disconnect": Kill the socket to stop pings/battery drain,
        // BUT do NOT update 'isConnected' or trigger UI changes to avoid crashes.
        print("🌍 GlobalSSEService: 🔌 Soft Disconnecting socket (preserving UI state)...")
        eventSource?.disconnect()
        eventSource = nil
        // We leave 'isConnected' alone. The UI won't know, and doesn't need to know while sleeping.
        // next appDidBecomeActive will reconnect.
    }
    
    // MARK: - Live Activity Helper
    
    @available(iOS 16.1, *)
    private func handleLiveActivityUpdate(_ event: EventSourceEvent) {
        // Debug raw data
        #if DEBUG
        let dataString = event.data
        // print("🌍 GlobalSSEService: 🔍 Processing Live Activity Event: \(dataString)")
        #endif

        guard let data = event.data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let generationId = json["generationId"] as? String else {
            return
        }
        
        let status = json["status"] as? String
        let progress = json["progress"] as? Double
        let message = json["message"] as? String
        let contentTypeString = json["contentType"] as? String
        
        // Map content type string to GenerationType
        let type: GenerationAttributes.GenerationType = (contentTypeString == "story_book") ? .book : .bedtimeStory
        
        // If completed or failed, end the activity AND stop background work
        if status == "completed" {
            LiveActivityManager.shared.endGenerationActivity(
                generationId: generationId,
                status: .completed
            )
            // Smart Suspend: Check if ANY valid work remains. Only stop if queue is empty AND we are in background.
            // Race Condition Fix: endGenerationActivity is async, so the activity might still report as 'generating' for a few ms.
            // We must manually exclude the current ID from the check or check if ONLY this one is left.
            let validWorkRemains = LiveActivityManager.shared.hasActiveActivities(excluding: generationId)
            
            if !validWorkRemains && isAppInBackground {
                stopBackgroundWork()
            } else {
                 #if DEBUG
                 print("🌍 GlobalSSEService: ⚠️ Job completed. Keeping connection (Background: \(isAppInBackground), Active Activities: \(validWorkRemains))")
                 #endif
            }
            
        } else if status == "failed" {
            LiveActivityManager.shared.endGenerationActivity(
                generationId: generationId,
                status: .failed
            )
            // Smart Suspend: Check if ANY valid work remains & Backgrounded
            let validWorkRemains = LiveActivityManager.shared.hasActiveActivities(excluding: generationId)
            
            if !validWorkRemains && isAppInBackground {
                stopBackgroundWork()
            }
            
        } else {
            // Otherwise update progress (and start if missing)
            if let progress = progress {
                LiveActivityManager.shared.updateGenerationProgress(
                    generationId: generationId,
                    progress: progress,
                    message: message,
                    type: type
                )
            }
        }
    }
}

// Extension to bridge the gap if EventSourceEvent doesn't have 'type' alias
// Assuming EventSourceEvent has 'event' property which maps to 'type' in SSE
extension EventSourceEvent {
    var type: String? { return event }
}
