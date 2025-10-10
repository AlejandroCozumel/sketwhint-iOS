import SwiftUI
import AVFoundation
import Combine

struct StoryPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioPlayer = SimpleAudioPlayer()

    let story: BedtimeStory

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Cover image
                    AsyncImage(url: URL(string: story.imageUrl)) { imagePhase in
                        switch imagePhase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity)
                                .frame(height: 300)
                                .clipped()
                                .cornerRadius(AppSizing.cornerRadius.lg)
                        case .failure(_):
                            Rectangle()
                                .fill(Color(hex: "#6366F1").opacity(0.2))
                                .frame(height: 300)
                                .cornerRadius(AppSizing.cornerRadius.lg)
                                .overlay(
                                    Image(systemName: "moon.stars")
                                        .font(.system(size: 60))
                                        .foregroundColor(Color(hex: "#6366F1"))
                                )
                        case .empty:
                            Rectangle()
                                .fill(AppColors.surfaceLight)
                                .frame(height: 300)
                                .shimmer()
                                .cornerRadius(AppSizing.cornerRadius.lg)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)

                    // Story info
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text(story.title)
                            .font(AppTypography.headlineLarge)
                            .foregroundColor(AppColors.textPrimary)

                        if let theme = story.theme {
                            HStack {
                                Image(systemName: "book.fill")
                                    .foregroundColor(Color(hex: "#6366F1"))
                                Text(theme)
                                    .font(AppTypography.bodyMedium)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }

                        HStack(spacing: AppSpacing.lg) {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .foregroundColor(AppColors.textSecondary)
                                Text("\(story.duration / 60) min")
                                    .font(AppTypography.captionLarge)
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            if let characterName = story.characterName {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.fill")
                                        .foregroundColor(AppColors.textSecondary)
                                    Text(characterName)
                                        .font(AppTypography.captionLarge)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }
                        }

                        Divider()

                        // Story text
                        if let storyText = story.storyText {
                            Text(storyText)
                                .font(AppTypography.bodyMedium)
                                .foregroundColor(AppColors.textPrimary)
                                .lineSpacing(6)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                }
                .padding(.vertical, AppSpacing.lg)
                .padding(.bottom, 120) // Space for player controls
            }
            .background(AppColors.backgroundLight)
            .navigationTitle("Story Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        audioPlayer.stop()
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#6366F1"))
                }
            }
            .overlay(alignment: .bottom) {
                audioPlayerControls
            }
            .onAppear {
                audioPlayer.loadAudio(from: story.audioUrl)
            }
            .onDisappear {
                audioPlayer.stop()
            }
        }
    }

    // MARK: - Audio Player Controls
    private var audioPlayerControls: some View {
        VStack(spacing: AppSpacing.md) {
            // Progress bar
            VStack(spacing: 4) {
                ProgressView(value: audioPlayer.progress)
                    .tint(Color(hex: "#6366F1"))

                HStack {
                    Text(formatTime(audioPlayer.currentTime))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)

                    Spacer()

                    Text(formatTime(audioPlayer.duration))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            // Play/Pause button
            HStack(spacing: AppSpacing.xl) {
                Button {
                    audioPlayer.seekBackward()
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 28))
                        .foregroundColor(AppColors.textPrimary)
                }
                .childSafeTouchTarget()

                Button {
                    if audioPlayer.isPlaying {
                        audioPlayer.pause()
                    } else {
                        audioPlayer.play()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#6366F1"))
                            .frame(width: 80, height: 80)

                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .childSafeTouchTarget()

                Button {
                    audioPlayer.seekForward()
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 28))
                        .foregroundColor(AppColors.textPrimary)
                }
                .childSafeTouchTarget()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(AppSpacing.lg)
        .background(.ultraThinMaterial)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)
    }

    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Simple Audio Player
@MainActor
class SimpleAudioPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var progress: Double = 0

    private var player: AVPlayer?
    private var timeObserver: Any?

    func loadAudio(from urlString: String) {
        guard let url = URL(string: urlString) else {
            print("❌ Invalid audio URL: \(urlString)")
            return
        }

        player = AVPlayer(url: url)

        // Observe playback time
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }

            self.currentTime = time.seconds

            if let duration = self.player?.currentItem?.duration.seconds, duration.isFinite {
                self.duration = duration
                self.progress = duration > 0 ? time.seconds / duration : 0
            }

            // Auto-stop at end
            if let duration = self.player?.currentItem?.duration.seconds,
               time.seconds >= duration - 0.5 {
                self.stop()
            }
        }

        // Get duration when ready
        player?.currentItem?.asset.loadValuesAsynchronously(forKeys: ["duration"]) { [weak self] in
            DispatchQueue.main.async {
                if let duration = self?.player?.currentItem?.duration.seconds, duration.isFinite {
                    self?.duration = duration
                }
            }
        }

        print("✅ Audio loaded: \(urlString)")
    }

    func play() {
        player?.play()
        isPlaying = true
        print("▶️ Playing audio")
    }

    func pause() {
        player?.pause()
        isPlaying = false
        print("⏸ Paused audio")
    }

    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        isPlaying = false
        currentTime = 0
        progress = 0
        print("⏹ Stopped audio")
    }

    func seekForward() {
        guard let currentTime = player?.currentTime() else { return }
        let newTime = CMTimeAdd(currentTime, CMTime(seconds: 15, preferredTimescale: 1))
        player?.seek(to: newTime)
        print("⏩ Seek forward 15s")
    }

    func seekBackward() {
        guard let currentTime = player?.currentTime() else { return }
        let newTime = CMTimeSubtract(currentTime, CMTime(seconds: 15, preferredTimescale: 1))
        player?.seek(to: newTime)
        print("⏪ Seek backward 15s")
    }

    deinit {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        player = nil
    }
}
