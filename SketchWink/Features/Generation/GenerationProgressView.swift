import SwiftUI

struct GenerationProgressView: View {
    let generation: Generation
    let onComplete: (Generation) -> Void
    let onError: (String) -> Void
    
    @StateObject private var generationService = GenerationService.shared
    @State private var currentGeneration: Generation
    @State private var progressStage: ProgressStage = .enhancing
    @State private var progressAnimation = 0.0
    @State private var isAnimating = false
    @Environment(\.dismiss) private var dismiss
    
    init(generation: Generation, onComplete: @escaping (Generation) -> Void, onError: @escaping (String) -> Void) {
        self.generation = generation
        self.onComplete = onComplete
        self.onError = onError
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
            await startPolling()
        }
        .onAppear {
            startAnimations()
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
                    Text(progressStage.icon)
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
            Text(progressStage.title)
                .font(AppTypography.headlineLarge)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            
            Text(progressStage.description)
                .font(AppTypography.bodyLarge)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
            
            // Show user prompt
            if !currentGeneration.userPrompt.isEmpty {
                VStack(spacing: AppSpacing.xs) {
                    Text("Creating:")
                        .font(AppTypography.captionLarge)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text("\"\(currentGeneration.userPrompt)\"")
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.primaryBlue)
                        .italic()
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(AppSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppSizing.cornerRadius.sm)
                        .fill(AppColors.primaryBlue.opacity(0.1))
                )
            }
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
                        .frame(width: geometry.size.width * progressStage.percentage, height: 8)
                        .animation(.easeInOut(duration: 0.5), value: progressStage.percentage)
                }
            }
            .frame(height: 8)
            
            // Percentage text
            Text("\(Int(progressStage.percentage * 100))%")
                .font(AppTypography.titleSmall)
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    // MARK: - Cancel Button
    private var cancelButtonView: some View {
        Button("Cancel") {
            dismiss()
        }
        .largeButtonStyle(backgroundColor: AppColors.buttonSecondary)
        .childSafeTouchTarget()
    }
    
    // MARK: - Methods
    private func startAnimations() {
        isAnimating = true
        progressAnimation = 360
    }
    
    private func startPolling() async {
        do {
            let completedGeneration = try await generationService.pollGenerationUntilComplete(
                id: currentGeneration.id,
                maxAttempts: 60
            )
            
            // Update to completion stage
            await MainActor.run {
                progressStage = .complete
            }
            
            // Small delay to show completion
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            onComplete(completedGeneration)
            
        } catch {
            await MainActor.run {
                onError(error.localizedDescription)
            }
        }
    }
}

// MARK: - Progress Stages
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