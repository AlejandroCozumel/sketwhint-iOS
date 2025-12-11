import Foundation
import Combine
import UIKit

// MARK: - Global SSE Service
/// Handles the persistent SSE connection to the server, managing authentication,
/// app lifecycle (background/foreground), and exponential backoff for reconnections.
/// Dispatches generic events to observers.
class GlobalSSEService: ObservableObject {
    static let shared = GlobalSSEService()

    // MARK: - Connection State
    @Published var isConnected = false
    @Published var connectionError: Error?
    @Published var lastEventAt: Date?
    
    // Core SSE client
    private var eventSource: EventSourceService?
    private var cancellables = Set<AnyCancellable>()
    
    // Authentication
    private var authToken: String?
    
    // Reconnection logic
    private var isReconnecting = false
    private var reconnectAttempt = 0
    private let maxReconnectAttempts = 5
    private var hasOpened = false
    
    // App lifecycle state
    private var isAppInBackground = false
    
    // Event Observers
    // Dictionary mapping event types to a set of closures
    private var observers: [String: [(EventSourceEvent) -> Void]] = [:]
    private var observersLock = NSLock()
    
    private init() {
        setupAppLifecycleObservers()
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
    func disconnect() {
        #if DEBUG
        print("🌍 GlobalSSEService: Disconnecting...")
        #endif
        
        eventSource?.disconnect()
        eventSource = nil
        
        isReconnecting = false
        reconnectAttempt = 0
        hasOpened = false
        authToken = nil // Clear token on manual disconnect
        
        DispatchQueue.main.async {
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
        #if DEBUG
        print("🌍 GlobalSSEService: 📱 App backgrounded. Suspending connection.")
        #endif
        
        // Disconnect to be a good citizen and save battery
        // We keep 'authToken' so we can reconnect later
        eventSource?.disconnect()
        eventSource = nil
        
        DispatchQueue.main.async {
            self.isConnected = false
        }
        
        hasOpened = false
    }
    
    @objc private func appDidBecomeActive() {
        isAppInBackground = false
        #if DEBUG
        print("🌍 GlobalSSEService: 📱 App foregrounded.")
        #endif
        
        guard authToken != nil else { return }
        
        if !isConnected {
            #if DEBUG
            print("🌍 GlobalSSEService: 📱 Restoring connection...")
            #endif
            reconnectAttempt = 0 // Reset attempts on manual/foreground action
            establishConnection()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// Extension to bridge the gap if EventSourceEvent doesn't have 'type' alias
// Assuming EventSourceEvent has 'event' property which maps to 'type' in SSE
extension EventSourceEvent {
    var type: String? { return event }
}
