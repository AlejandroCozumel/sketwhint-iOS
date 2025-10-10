import SwiftUI
import AVFoundation
import Combine

struct StoryPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioPlayer: LyricsAudioPlayer

    let story: BedtimeStory

    init(story: BedtimeStory) {
        self.story = story
        self._audioPlayer = StateObject(wrappedValue: LyricsAudioPlayer(story: story))

        #if DEBUG
        print("📖 StoryPlayerView initialized")
        print("   - Story ID: \(story.id)")
        print("   - Title: \(story.title)")
        print("   - Has storyText: \(story.storyText != nil)")
        if let storyText = story.storyText {
            print("   - Story text length: \(storyText.count) characters")
            print("   - First 100 chars: \(String(storyText.prefix(100)))")
        }
        print("   - Has wordTimestamps: \(story.wordTimestamps != nil)")
        if let timestamps = story.wordTimestamps {
            print("   - Timestamps length: \(timestamps.count) characters")
        }
        #endif
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundLight
                    .ignoresSafeArea()

                if audioPlayer.hasLyrics {
                    // Lyrics Mode (Apple Music style)
                    lyricsView
                        .onAppear {
                            #if DEBUG
                            print("🎵 Showing LYRICS VIEW")
                            print("   - Has storyText: \(story.storyText != nil)")
                            #endif
                        }
                } else {
                    // Simple Mode (current implementation)
                    simplePlayerView
                        .onAppear {
                            #if DEBUG
                            print("📖 Showing SIMPLE VIEW")
                            #endif
                        }
                }
            }
            .navigationTitle(audioPlayer.hasLyrics ? "" : "Story Player")
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

    // MARK: - Simple Player View (No Lyrics)
    private var simplePlayerView: some View {
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
    }

    // MARK: - Lyrics View (Apple Music Style)
    private var lyricsView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    // Top spacing
                    Color.clear.frame(height: AppSpacing.xl)

                    // Cover image (smaller in lyrics mode)
                    AsyncImage(url: URL(string: story.imageUrl)) { imagePhase in
                        switch imagePhase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 200, height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg))
                                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                        case .failure(_):
                            Rectangle()
                                .fill(Color(hex: "#6366F1").opacity(0.2))
                                .frame(width: 200, height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg))
                                .overlay(
                                    Image(systemName: "moon.stars")
                                        .font(.system(size: 40))
                                        .foregroundColor(Color(hex: "#6366F1"))
                                )
                        case .empty:
                            Rectangle()
                                .fill(AppColors.surfaceLight)
                                .frame(width: 200, height: 200)
                                .shimmer()
                                .clipShape(RoundedRectangle(cornerRadius: AppSizing.cornerRadius.lg))
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .padding(.bottom, AppSpacing.xl)

                    // Title
                    Text(story.title)
                        .font(AppTypography.headlineMedium)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.bottom, AppSpacing.xl)

                    // Full story text with highlighted current word
                    if let storyText = story.storyText {
                        Text(audioPlayer.createHighlightedText(from: storyText))
                            .font(AppTypography.bodyLarge)
                            .lineSpacing(8)
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, AppSpacing.lg)
                            .id("story-text")
                            .onAppear {
                                // 🚀 OPTIMIZATION: Prepare karaoke sync on first appearance
                                audioPlayer.prepareKaraokeSync(with: storyText)
                            }
                    }

                    // Bottom spacing
                    Color.clear.frame(height: 180) // Space for player controls
                }
            }
            .onChange(of: audioPlayer.currentWordIndex) {
                // Auto-scroll is handled by the highlighted word staying visible
                // SwiftUI handles this automatically with ScrollView
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

// MARK: - Lyrics Audio Player
@MainActor
class LyricsAudioPlayer: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var progress: Double = 0
    @Published var currentWordIndex: Int = 0

    let hasLyrics: Bool
    let words: [WordTimestamp]

    // 🚀 OPTIMIZATION: Pre-computed word position cache (Apple Music style)
    private var wordPositionCache: [(range: Range<AttributedString.Index>, word: String)]?
    private var karaokeWords: [KaraokeWord] = []

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var updateTimer: Timer?

    init(story: BedtimeStory) {
        // Parse word timestamps
        if let timestampsJSON = story.wordTimestamps,
           !timestampsJSON.isEmpty,
           let data = timestampsJSON.data(using: .utf8),
           let timestamps = try? JSONDecoder().decode([WordTimestamp].self, from: data) {
            self.hasLyrics = true
            self.words = timestamps

            #if DEBUG
            print("🎵 Lyrics mode enabled - \(timestamps.count) words")
            #endif
        } else {
            self.hasLyrics = false
            self.words = []

            #if DEBUG
            print("📖 Simple mode - no word timestamps")
            #endif
        }
    }

    func loadAudio(from urlString: String) {
        guard let url = URL(string: urlString) else {
            print("❌ Invalid audio URL: \(urlString)")
            return
        }

        player = AVPlayer(url: url)

        // 🚀 CRITICAL FIX: High-precision time observer for smooth karaoke sync
        // Apple Music uses ~10-30ms intervals for lyrics synchronization
        let interval = CMTime(seconds: 0.02, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }

            Task { @MainActor [weak self] in
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
        }

        // Get duration when ready
        Task { @MainActor [weak self] in
            guard let self = self,
                  let asset = self.player?.currentItem?.asset else { return }

            do {
                let duration = try await asset.load(.duration)
                if duration.seconds.isFinite {
                    self.duration = duration.seconds
                }
            } catch {
                print("❌ Failed to load duration: \(error.localizedDescription)")
            }
        }

        // Start lyrics sync timer if we have lyrics
        if hasLyrics {
            startLyricsSync()
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
        currentWordIndex = 0
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

    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 1)
        player?.seek(to: cmTime)
        print("⏭ Seek to \(time)s")
    }

    // MARK: - Lyrics Synchronization
    private func startLyricsSync() {
        // 🚀 OPTIMIZATION: 60fps update rate (16.67ms) - Apple Music style
        // High refresh rate ensures no missed words and instant visual feedback
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.0167, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateCurrentWord()
            }
        }

        #if DEBUG
        print("⚡ Lyrics sync started: 60fps (16.67ms intervals)")
        #endif
    }

    private func updateCurrentWord() {
        guard hasLyrics, !karaokeWords.isEmpty else { return }

        // 🚀 OPTIMIZATION: Binary search O(log n) with look-ahead strategy
        // Words stay highlighted until the next word starts (no gaps)
        let newIndex = KaraokeMatcher.findCurrentWordIndex(
            currentTime: currentTime,
            karaokeWords: karaokeWords
        )

        // Update immediately when word changes
        if newIndex != currentWordIndex && newIndex != -1 {
            currentWordIndex = newIndex

            #if DEBUG
            let word = karaokeWords[newIndex]
            print("🎯 Word [\(newIndex)]: '\(word.originalWord)' at \(String(format: "%.3f", currentTime))s (start: \(String(format: "%.3f", word.start))s)")
            #endif
        }
    }

    // MARK: - Text Highlighting
    func createHighlightedText(from storyText: String) -> AttributedString {
        var attributed = AttributedString(storyText)

        // If no lyrics or invalid index, return plain text
        guard hasLyrics, currentWordIndex >= 0, currentWordIndex < karaokeWords.count else {
            return attributed
        }

        // 🚀 OPTIMIZATION: Use pre-computed cache instead of rebuilding every time
        if wordPositionCache == nil {
            wordPositionCache = buildWordPositionCache(for: storyText)

            #if DEBUG
            print("📦 Word position cache built: \(wordPositionCache?.count ?? 0) words")
            #endif
        }

        // 🎨 Highlight current word with vibrant orange (no bold)
        if let cachedRange = wordPositionCache?[safe: currentWordIndex]?.range {
            attributed[cachedRange].foregroundColor = Color(hex: "#EA580C") // Vibrant orange-600
        }

        return attributed
    }

    // 🚀 OPTIMIZATION: Build word position cache once (Apple Music approach)
    private func buildWordPositionCache(for text: String) -> [(range: Range<AttributedString.Index>, word: String)] {
        var cache: [(range: Range<AttributedString.Index>, word: String)] = []
        let attributedText = AttributedString(text)

        // Replace newlines with spaces to match Whisper's view
        let cleanedText = text.replacingOccurrences(of: "\n", with: " ")
        var wordPositions: [(word: String, range: Range<String.Index>)] = []

        // Parse all word positions in one pass
        var currentWord = ""
        var wordStart: String.Index?

        for charIndex in cleanedText.indices {
            let char = cleanedText[charIndex]

            if char.isLetter || char.isNumber || char == "'" {
                if wordStart == nil {
                    wordStart = charIndex
                }
                currentWord.append(char)
            } else {
                if !currentWord.isEmpty, let start = wordStart {
                    wordPositions.append((word: currentWord, range: start..<charIndex))
                    currentWord = ""
                    wordStart = nil
                }
            }
        }

        // Handle last word
        if !currentWord.isEmpty, let start = wordStart {
            wordPositions.append((word: currentWord, range: start..<cleanedText.endIndex))
        }

        // Convert to AttributedString ranges
        for position in wordPositions {
            let startOffset = cleanedText.distance(from: cleanedText.startIndex, to: position.range.lowerBound)
            let endOffset = cleanedText.distance(from: cleanedText.startIndex, to: position.range.upperBound)

            let rangeStart = attributedText.index(attributedText.startIndex, offsetByCharacters: startOffset)
            let rangeEnd = attributedText.index(attributedText.startIndex, offsetByCharacters: endOffset)

            cache.append((range: rangeStart..<rangeEnd, word: position.word))
        }

        return cache
    }

    // 🚀 OPTIMIZATION: Initialize karaoke words for binary search
    func prepareKaraokeSync(with storyText: String) {
        guard hasLyrics else { return }

        // Convert WordTimestamp to KaraokeWord for binary search compatibility
        karaokeWords = words.enumerated().map { index, timestamp in
            KaraokeWord(
                originalWord: timestamp.word,
                normalizedWord: timestamp.word.lowercased(),
                start: timestamp.start,
                end: timestamp.end,
                index: index
            )
        }

        #if DEBUG
        print("🎼 Karaoke words prepared: \(karaokeWords.count) words")
        if let first = karaokeWords.first, let last = karaokeWords.last {
            print("   - First word: '\(first.originalWord)' at \(String(format: "%.2f", first.start))s")
            print("   - Last word: '\(last.originalWord)' at \(String(format: "%.2f", last.end))s")
        }
        #endif
    }

    deinit {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        updateTimer?.invalidate()
        player = nil
    }
}

// MARK: - Array Safe Subscript Extension
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
