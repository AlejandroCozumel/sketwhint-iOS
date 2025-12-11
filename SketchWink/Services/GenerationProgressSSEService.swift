import Foundation
import Combine
import UIKit

// MARK: - Generation Progress SSE Service
/// Manages the tracking of a specific generation's progress.
/// Delegates the actual connection to `GlobalSSEService` but handles
/// parsing logic, polling fallback, and progress calculation.
class GenerationProgressSSEService: ObservableObject {
    static let shared = GenerationProgressSSEService()

    // Current generation progress state
    @Published var currentProgress: GenerationProgress?
    @Published var isConnected = false
    @Published var connectionError: Error?
    
    // Callbacks
    var onProgressUpdate: ((GenerationProgress) -> Void)?
    var onGenerationComplete: ((String) -> Void)?
    var onError: ((Error) -> Void)?
    
    // Internal state
    var trackingGenerationId: String?
    private var cancellables = Set<AnyCancellable>()
    
    // Polling fallback
    private var pollingTimer: Timer?
    private var isPolling = false
    private let pollingInterval: TimeInterval = 5.0
    private var maxReconnectAttempts = 5 // Kept for polling logic threshold compatibility
    
    private init() {
        setupGlobalObservers()
    }
    
    // MARK: - Public API
    
    /// Connects to the global SSE service.
    /// Note: This now just proxies to GlobalSSEService.
    func connectToUserProgress(authToken: String, trackingGenerationId: String? = nil) {
        // Update tracking ID if provided
        if let trackingGenerationId = trackingGenerationId, !trackingGenerationId.isEmpty {
            self.trackingGenerationId = trackingGenerationId
            resetProgressState(for: trackingGenerationId)
        }
        
        // Connect global service
        GlobalSSEService.shared.connect(authToken: authToken)
    }
    
    /// Starts tracking a specific generation ID from the stream
    func startTrackingGeneration(_ generationId: String) {
        #if DEBUG
        print("🔗 GenerationProgressManager: Start tracking \(generationId)")
        #endif
        
        self.trackingGenerationId = generationId
        resetProgressState(for: generationId)
        
        // Stop any existing polling since we assume SSE is primary
        stopPollingFallback()
    }
    
    /// Stops tracking the current generation but keeps the global connection alive.
    /// This is called when the Generation sheet is dismissed.
    func disconnect() {
        #if DEBUG
        print("🔗 GenerationProgressManager: Stop tracking current generation")
        #endif
        
        // We do NOT disconnect the GlobalSSEService here.
        // We just stop tracking the specific ID and stop polling.
        trackingGenerationId = nil
        currentProgress = nil
        stopPollingFallback()
    }
    
    // MARK: - Internal Setup
    
    private func setupGlobalObservers() {
        // 1. Observe Global Connection State
        GlobalSSEService.shared.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.handleGlobalConnectionChange(isConnected)
            }
            .store(in: &cancellables)
            
        GlobalSSEService.shared.$connectionError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.connectionError = error
            }
            .store(in: &cancellables)
            
        // 2. Observe 'progress' events from Global Service
        GlobalSSEService.shared.observe(event: "progress") { [weak self] event in
            self?.handleProgressEvent(event)
        }
    }
    
    private func handleGlobalConnectionChange(_ isConnected: Bool) {
        self.isConnected = isConnected
        
        if isConnected {
            // If we reconnected and are tracking something, stop polling
            if trackingGenerationId != nil {
                stopPollingFallback()
            }
        } else {
            // If disconnected and tracking, potentially start polling
            if trackingGenerationId != nil {
                // We give the global service a moment to reconnect (it has its own backoff).
                // If it takes too long, we could start polling.
                // For now, let's wait for the global service to fail or explicit error.
                // Or we can start polling immediately as a backup.
                
                // Let's rely on the GlobalSSEService's reliability first.
                // If the app is in foreground and we are disconnected, start polling after a delay?
                schedulePollingCheck()
            }
        }
    }
    
    private func handleProgressEvent(_ event: EventSourceEvent) {
        let dataString = event.data
        guard !dataString.isEmpty else { return }
        guard let data = dataString.data(using: .utf8) else { return }
        
        do {
            let progressData = try JSONDecoder().decode(GenerationProgressData.self, from: data)
            
            // Filter for equality if we are tracking a specific ID
            // If the event doesn't have an ID, we assume it matches our tracking ID (legacy behavior)
            let incomingId = progressData.generationId?.trimmingCharacters(in: .whitespacesAndNewlines)
            let isRelevant = (incomingId == nil) || (incomingId == trackingGenerationId)
            
            if isRelevant {
                processProgressData(progressData)
            }
            
        } catch {
            // Ignore decoding errors
        }
    }
    
    private func processProgressData(_ data: GenerationProgressData) {
        // Calculate progress
        let effectiveId = data.generationId ?? trackingGenerationId ?? ""
        let status = GenerationStatus(rawValue: data.status ?? "queued") ?? .queued
        let numericProgress = data.progress ?? calculateProgress(status: status)
        
        let progress = GenerationProgress(
            generationId: effectiveId,
            status: status,
            progress: numericProgress,
            imageCount: data.imageCount ?? 0,
            error: data.error
        )
        
        DispatchQueue.main.async {
            self.currentProgress = progress
        }
        
        onProgressUpdate?(progress)
        
        if status == .completed {
            onGenerationComplete?(effectiveId)
            
            // Refresh token balance
            Task { @MainActor in
                await TokenBalanceManager.shared.refresh()
            }
        } else if status == .failed {
            onError?(GenerationProgressError.generationFailed(data.error ?? "Unknown error"))
        }
    }
    
    private func resetProgressState(for id: String) {
        DispatchQueue.main.async {
            self.currentProgress = GenerationProgress(
                generationId: id,
                status: .queued,
                progress: 0,
                imageCount: 0,
                error: nil
            )
        }
    }
    
    // MARK: - Polling Fallback Logic
    
    private func schedulePollingCheck() {
        // If still disconnected after 5 seconds, start polling
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self = self else { return }
            if !self.isConnected && self.trackingGenerationId != nil {
                self.startPollingFallback()
            }
        }
    }
    
    private func startPollingFallback() {
        guard !isPolling, let trackingId = trackingGenerationId else { return }
        
        isPolling = true
        #if DEBUG
        print("🔗 GenerationProgressManager: Starting polling fallback for \(trackingId)")
        #endif
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            self?.pollGenerationStatus()
        }
        pollGenerationStatus()
    }
    
    private func stopPollingFallback() {
        isPolling = false
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    private func pollGenerationStatus() {
        guard let trackingId = trackingGenerationId else { return }
        
        Task { @MainActor in
            do {
                let generation = try await GenerationService.shared.getGeneration(id: trackingId)
                
                // Convert Generation model to Progress Data format
                let data = GenerationProgressData(
                    type: "progress",
                    generationId: generation.id,
                    status: generation.status,
                    progress: nil, // Will be calculated
                    userId: nil,
                    replicateStatus: nil,
                    hasOutput: generation.images != nil,
                    imageCount: generation.images?.count,
                    error: nil
                )
                
                self.processProgressData(data)
                
                if generation.status == "completed" || generation.status == "failed" {
                    self.stopPollingFallback()
                }
                
            } catch {
                #if DEBUG
                print("🔗 GenerationProgressManager: Polling failed - \(error)")
                #endif
            }
        }
    }

    // MARK: - Helper Methods
    
    private func calculateProgress(status: GenerationStatus) -> Int {
        switch status {
        case .queued: return 0
        case .starting: return 5
        case .processing: return 20 
        case .completing: return 90
        case .completed: return 100
        case .failed: return 0
        case .cancelled: return 0
        }
    }
    
    private func parseGenerationStatus(_ status: String) -> GenerationStatus {
        return GenerationStatus(rawValue: status) ?? .queued
    }
}

// MARK: - Supporting Stubs to match existing calls
// These extensions ensure we don't break existing 'GenerationProgressData' usage if it was inline
// (Assuming 'GenerationProgressData' is defined in this file or a shared model file. 
//  Since I am rewriting this file, I need to include the struct if it was here.)

struct GenerationProgressData: Codable {
    let type: String
    let generationId: String?
    let status: String?
    let progress: Int?
    let userId: String?
    let replicateStatus: String?
    let hasOutput: Bool?
    let imageCount: Int?
    let error: String?
}

// Ensure the enum is available if not elsewhere
// enum GenerationStatus: String, Codable { ... } 
// (It seems likely it is in GenerationModels.swift, verified in step 17 it is imported)
