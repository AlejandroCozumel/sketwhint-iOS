import SwiftUI

struct GenerationProgressView: View {
    let generation: Generation
    let onComplete: (Generation) -> Void
    let onError: (String) -> Void
    let onCancel: (() -> Void)?

    @StateObject private var generationService = GenerationService.shared
    @StateObject private var progressSSEService = GenerationProgressSSEService.shared
    @State private var currentGeneration: Generation
    @State private var progressAnimation = 0.0
    @State private var isAnimating = false
    @State private var closeButtonCountdown = 60
    @State private var closeButtonTimer: Timer?
    @Environment(\.dismiss) private var dismiss

    init(generation: Generation, onComplete: @escaping (Generation) -> Void, onError: @escaping (String) -> Void, onCancel: (() -> Void)? = nil) {
        self.generation = generation
        self.onComplete = onComplete
        self.onError = onError
        self.onCancel = onCancel
        self._currentGeneration = State(initialValue: generation)
    }
    
    var body: some View {
        ZStack {
            // Background
            AppColors.backgroundLight
                .ignoresSafeArea()
            
            VStack(spacing: AppSpacing.xxl) {
                
                // Progress Animation
                progressAnimationView
                
                // Status Content
                progressContentView
                
                // Progress Bar
                progressBarView
                
                Spacer()
                
                // Cancel Button
                cancelButtonView
            }
            .contentPadding()
        }
        .task {
            await startSSEConnection()
        }
        .onAppear {
            startAnimations()
            startCloseButtonCountdown()
        }
        .onDisappear {
            stopCloseButtonCountdown()
        }
    }
    
    // MARK: - Progress Animation View
    private var progressAnimationView: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .stroke(AppColors.coloringPagesColor.opacity(0.3), lineWidth: 4)
                .frame(width: 200, height: 200)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .opacity(isAnimating ? 0.0 : 1.0)
                .animation(
                    .easeInOut(duration: 2.0).repeatForever(autoreverses: false),
                    value: isAnimating
                )
            
            // Middle ring
            Circle()
                .stroke(AppColors.coloringPagesColor.opacity(0.5), lineWidth: 3)
                .frame(width: 160, height: 160)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .opacity(isAnimating ? 0.3 : 0.8)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: false),
                    value: isAnimating
                )
            
            // Inner circle with icon
            Circle()
                .fill(AppColors.coloringPagesColor)
                .frame(width: 120, height: 120)
                .shadow(
                    color: AppColors.coloringPagesColor.opacity(0.4),
                    radius: 20,
                    x: 0,
                    y: 10
                )
                .scaleEffect(isAnimating ? 1.05 : 1.0)
                .animation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: isAnimating
                )
                .overlay(
                    Text(currentStatus.icon)
                        .font(.system(size: 50))
                        .rotationEffect(.degrees(progressAnimation))
                        .animation(
                            .linear(duration: 2.0).repeatForever(autoreverses: false),
                            value: progressAnimation
                        )
                )
        }
    }
    
    // MARK: - Progress Content
    private var progressContentView: some View {
        VStack(spacing: AppSpacing.md) {
            Text(currentStatus.displayMessage)
                .font(AppTypography.headlineLarge)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            
            Text(currentStatus.detailedDescription)
                .font(AppTypography.bodyLarge)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            
            // Show generation context
            VStack(spacing: AppSpacing.xs) {
                Text(LocalizedStringKey("progress.creating"))
                    .font(AppTypography.captionLarge)
                    .foregroundColor(AppColors.textSecondary)

                if let userPrompt = currentGeneration.userPrompt, !userPrompt.isEmpty {
                    // Text-based generation: show user prompt
                    Text("\"\(userPrompt)\"")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.primaryBlue)
                        .italic()
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                } else {
                    // Image-based generation: show creative message
                    Text(LocalizedStringKey("progress.transforming.photo"))
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.primaryPurple)
                        .italic()
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                    .fill(AppColors.primaryBlue.opacity(0.1))
            )
        }
    }
    
    // MARK: - Progress Bar
    private var progressBarView: some View {
        VStack(spacing: AppSpacing.sm) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                        .fill(AppColors.textSecondary.opacity(0.2))
                        .frame(height: 8)
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                        .fill(AppColors.coloringPagesColor)
                        .frame(width: geometry.size.width * currentProgressPercentage, height: 8)
                        .animation(.easeInOut(duration: 0.5), value: currentProgressPercentage)
                }
            }
            .frame(height: 8)
            
            // Percentage text
            Text("\(Int(currentProgressPercentage * 100))%")
                .font(AppTypography.titleSmall)
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    // MARK: - Close Button with Countdown
    private var cancelButtonView: some View {
        Button(closeButtonTitle) {
            // Call onCancel to reset parent state
            onCancel?()
            dismiss()
        }
        .largeButtonStyle(backgroundColor: closeButtonCountdown > 0 ? AppColors.buttonDisabled : AppColors.errorRed)
        .disabled(closeButtonCountdown > 0)
        .opacity(closeButtonCountdown > 0 ? 0.6 : 1.0)
        .childSafeTouchTarget()
    }
    
    private var closeButtonTitle: String {
        if closeButtonCountdown > 0 {
            return String(format: NSLocalizedString("progress.close.countdown", comment: ""), closeButtonCountdown)
        } else {
            return NSLocalizedString("progress.close", comment: "")
        }
    }
    
    // MARK: - Computed Properties
    private var currentStatus: GenerationStatus {
        return progressSSEService.currentProgress?.status ?? .queued
    }
    
    private var currentProgressPercentage: Double {
        return progressSSEService.currentProgress?.progressPercentage ?? 0.0
    }
    
    // MARK: - Methods
    private func startAnimations() {
        isAnimating = true
        progressAnimation = 360
    }
    
    private func startCloseButtonCountdown() {
        // Reset countdown to 60 seconds
        closeButtonCountdown = 60
        
        // Cancel any existing timer
        stopCloseButtonCountdown()
        
        // Start countdown timer
        closeButtonTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if closeButtonCountdown > 0 {
                closeButtonCountdown -= 1
            } else {
                stopCloseButtonCountdown()
            }
        }
    }
    
    private func stopCloseButtonCountdown() {
        closeButtonTimer?.invalidate()
        closeButtonTimer = nil
    }
    
    private func startSSEConnection() async {
        // Get auth token
        guard let token = try? KeychainManager.shared.retrieveToken() else {
            onError("Authentication token not found")
            return
        }
        
        #if DEBUG
        print("🔗 GenerationProgressView: Starting SSE connection for generation \(currentGeneration.id)")
        #endif
        
        // Set up progress callbacks
        progressSSEService.onGenerationComplete = { generationId in
            Task {
                await MainActor.run {
                    // Handle completion by calling the onComplete callback
                    Task {
                        do {
                            let completedGeneration = try await generationService.getGeneration(id: generationId)
                            // Small delay for completion animation
                            try await Task.sleep(nanoseconds: 1_000_000_000)
                            await MainActor.run {
                                onComplete(completedGeneration)
                            }
                        } catch {
                            await MainActor.run {
                                onError(error.localizedDescription)
                            }
                        }
                    }
                }
            }
        }
        
        progressSSEService.onError = { error in
            Task {
                await MainActor.run {
                    onError(error.localizedDescription)
                }
            }
        }
        
        #if DEBUG
        print("🔗 GenerationProgressView: Will track generation ID: '\(currentGeneration.id)'")
        #endif
        
        // Start tracking this specific generation (SSE should already be connected from GenerationView)
        progressSSEService.startTrackingGeneration(currentGeneration.id)
        
        #if DEBUG
        print("🔗 GenerationProgressView: SSE connection status: \(progressSSEService.isConnected)")
        print("🔗 GenerationProgressView: Started tracking generation: \(currentGeneration.id)")
        #endif
        
        // Set up a timeout fallback - if we aren't advancing after 10 seconds, start polling
        Task {
            do {
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                
                if shouldTriggerPollingFallback() {
                    
                    #if DEBUG
                    print("🔗 GenerationProgressView: ⚠️ Progress has not advanced, starting polling fallback")
                    #endif
                    
                    await startPollingFallback()
                }
            } catch {
                #if DEBUG
                print("🔗 GenerationProgressView: Timeout task interrupted: \(error)")
                #endif
            }
        }
        
        // Also try to fetch current status from backend in case it's already progressing
        Task {
            // Add a small delay to let SSE potentially catch up first
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            do {
                let updatedGeneration = try await generationService.getGeneration(id: currentGeneration.id)
                
                #if DEBUG
                print("🔗 GenerationProgressView: Fetched current status: \(updatedGeneration.status)")
                print("🔗 GenerationProgressView: Current SSE progress status: \(progressSSEService.currentProgress?.status.rawValue ?? "nil")")
                #endif
                
                // Only update if SSE hasn't already updated to a more advanced status
                let currentSSEStatus = progressSSEService.currentProgress?.status ?? .queued
                let backendStatus = GenerationStatus(rawValue: updatedGeneration.status) ?? .queued
                
                // Update if backend is ahead of our SSE status
                if shouldUpdateToBackendStatus(currentSSE: currentSSEStatus, backend: backendStatus) {
                    let currentProgress = GenerationProgress(
                        generationId: updatedGeneration.id,
                        status: backendStatus,
                        progress: progressForStatus(backendStatus, from: updatedGeneration),
                        imageCount: updatedGeneration.images?.count ?? 0,
                        error: updatedGeneration.errorMessage
                    )
                    
                    #if DEBUG
                    print("🔗 GenerationProgressView: Updating progress from backend - SSE: \(currentSSEStatus.rawValue) → Backend: \(backendStatus.rawValue)")
                    #endif
                    
                    await MainActor.run {
                        progressSSEService.currentProgress = currentProgress
                    }
                } else {
                    #if DEBUG
                    print("🔗 GenerationProgressView: No update needed - SSE status \(currentSSEStatus.rawValue) is current")
                    #endif
                }
            } catch {
                #if DEBUG
                print("🔗 GenerationProgressView: Failed to fetch current status: \(error)")
                #endif
            }
        }
    }

    // MARK: - Helper Methods
    private func shouldTriggerPollingFallback() -> Bool {
        guard let currentProgress = progressSSEService.currentProgress else {
            return true
        }

        // Only react to the generation we started
        guard currentProgress.generationId == currentGeneration.id else {
            return false
        }

        // Don't fallback once we reached a terminal state
        switch currentProgress.status {
        case .completed, .failed:
            return false
        default:
            break
        }

        // If we haven't moved beyond the initial phase (<=10%) assume we are stale
        return currentProgress.progress <= 10
    }

    private func shouldUpdateToBackendStatus(currentSSE: GenerationStatus, backend: GenerationStatus) -> Bool {
        // Define status priority order
        let statusOrder: [GenerationStatus] = [.queued, .starting, .processing, .completing, .completed, .failed]
        
        guard let currentIndex = statusOrder.firstIndex(of: currentSSE),
              let backendIndex = statusOrder.firstIndex(of: backend) else {
            return false
        }
        
        // Update if backend status is more advanced than SSE status
        return backendIndex > currentIndex
    }
    
    private func progressForStatus(_ status: GenerationStatus, from generation: Generation) -> Int {
        // Use backend progress if available, otherwise use default progress for status
        if let backendProgress = generation.progress {
            return backendProgress
        }
        
        // Default progress values for each status
        switch status {
        case .queued: return 0
        case .starting: return 10
        case .processing: return 50
        case .completing: return 90
        case .completed: return 100
        case .failed: return 0
        }
    }
    
    // MARK: - Polling Fallback
    private func startPollingFallback() async {
        #if DEBUG
        print("🔗 GenerationProgressView: Starting polling fallback")
        #endif
        
        for attempt in 1...30 { // 30 attempts, 2 seconds each = 1 minute max
            do {
                let generation = try await generationService.getGeneration(id: currentGeneration.id)
                
                let progress = GenerationProgress(
                    generationId: generation.id,
                    status: GenerationStatus(rawValue: generation.status) ?? .queued,
                    progress: generation.progress ?? (generation.status == "completed" ? 100 : 0),
                    imageCount: generation.images?.count ?? 0,
                    error: generation.errorMessage
                )
                
                await MainActor.run {
                    progressSSEService.currentProgress = progress
                }
                
                #if DEBUG
                print("🔗 GenerationProgressView: Polling update - Status: \(generation.status), Progress: \(progress.progress)%")
                #endif
                
                // Check if completed
                if generation.status == "completed" {
                    #if DEBUG
                    print("🔗 GenerationProgressView: Polling detected completion")
                    #endif
                    
                    progressSSEService.onGenerationComplete?(generation.id)
                    return
                } else if generation.status == "failed" {
                    let error = GenerationProgressError.generationFailed(generation.errorMessage ?? "Generation failed")
                    progressSSEService.onError?(error)
                    return
                }
                
                // Wait 2 seconds before next poll
                try await Task.sleep(nanoseconds: 2_000_000_000)
                
            } catch {
                #if DEBUG
                print("🔗 GenerationProgressView: Polling error: \(error)")
                #endif
                
                // Wait before retrying
                do {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                } catch {
                    // If sleep fails, break out of polling loop
                    #if DEBUG
                    print("🔗 GenerationProgressView: Sleep interrupted, stopping polling")
                    #endif
                    break
                }
            }
        }
        
        #if DEBUG
        print("🔗 GenerationProgressView: Polling timeout after 1 minute")
        #endif
    }
}

// MARK: - GenerationStatus Extension for UI
extension GenerationStatus {
    var detailedDescription: String {
        switch self {
        case .queued:
            return NSLocalizedString("progress.queued.description", comment: "")
        case .starting:
            return NSLocalizedString("progress.starting.description", comment: "")
        case .processing:
            return NSLocalizedString("progress.processing.description", comment: "")
        case .completing:
            return NSLocalizedString("progress.completing.description", comment: "")
        case .completed:
            return NSLocalizedString("progress.completed.description", comment: "")
        case .failed:
            return NSLocalizedString("progress.failed.description", comment: "")
        }
    }
}

// MARK: - Legacy Progress Stages (Kept for backwards compatibility)
enum ProgressStage {
    case enhancing
    case generating
    case optimizing
    case complete
    
    var title: String {
        switch self {
        case .enhancing:
            return "Enhancing Your Prompt"
        case .generating:
            return "Creating Your Art"
        case .optimizing:
            return "Adding Final Touches"
        case .complete:
            return "Your Coloring Page is Ready!"
        }
    }
    
    var description: String {
        switch self {
        case .enhancing:
            return "Our AI is making your prompt even better for amazing results"
        case .generating:
            return "Generating your unique coloring page with beautiful details"
        case .optimizing:
            return "Preparing your high-quality coloring page for download"
        case .complete:
            return "Time to start coloring your masterpiece!"
        }
    }
    
    var icon: String {
        switch self {
        case .enhancing:
            return "✨"
        case .generating:
            return "🎨"
        case .optimizing:
            return "⚡"
        case .complete:
            return "🎉"
        }
    }
    
    var percentage: Double {
        switch self {
        case .enhancing:
            return 0.2
        case .generating:
            return 0.7
        case .optimizing:
            return 0.9
        case .complete:
            return 1.0
        }
    }
}

// MARK: - Enhanced Polling with Progress Updates
extension GenerationService {
    func pollGenerationUntilComplete(
        id: String,
        maxAttempts: Int = 60,
        progressCallback: ((ProgressStage) -> Void)? = nil
    ) async throws -> Generation {
        
        var currentStage: ProgressStage = .enhancing
        progressCallback?(currentStage)
        
        for attempt in 1...maxAttempts {
            let generation = try await getGeneration(id: id)
            
            // Update progress based on time elapsed
            let progress = Double(attempt) / Double(maxAttempts)
            if progress > 0.3 && currentStage == .enhancing {
                currentStage = .generating
                progressCallback?(currentStage)
            } else if progress > 0.7 && currentStage == .generating {
                currentStage = .optimizing
                progressCallback?(currentStage)
            }
            
            switch generation.status {
            case "completed":
                currentStage = .complete
                progressCallback?(currentStage)
                return generation
            case "failed":
                throw GenerationError.generationFailed(generation.errorMessage ?? "Generation failed")
            case "processing":
                // Wait 2 seconds before next poll
                try await Task.sleep(nanoseconds: 2_000_000_000)
                continue
            default:
                throw GenerationError.unknownStatus(generation.status)
            }
        }
        
        throw GenerationError.timeout
    }
}
