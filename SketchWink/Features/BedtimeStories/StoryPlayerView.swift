import SwiftUI
import UIKit
import AVFoundation
import Combine

struct StoryPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @StateObject private var audioPlayer: LyricsAudioPlayer
    @State private var isPreparingShare = false
    @State private var isDeleting = false
    @State private var showingShareSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingErrorAlert = false
    @State private var errorMessage: String?
    @State private var shareableAudioURL: URL?
    @State private var isSeeking = false

    let story: BedtimeStory
    private let onStoryDeleted: ((String) -> Void)?

    init(story: BedtimeStory, onStoryDeleted: ((String) -> Void)? = nil) {
        self.story = story
        self.onStoryDeleted = onStoryDeleted
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

    private var voiceName: String? {
        guard let voiceId = story.voiceId,
              let voices = BedtimeStoriesService.shared.config?.voices else {
            return nil
        }
        return voices.first { $0.id == voiceId }?.name
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d min", minutes, remainingSeconds)
    }

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.backgroundLight
                    .ignoresSafeArea()

                playerView
            }
            .navigationTitle(audioPlayer.hasLyrics ? "" : "stories.story.player".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        audioPlayer.stop()
                        dismiss()
                    }) {
                        ZStack {
                            Circle()
                                .fill(AppColors.surfaceLight)
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(AppColors.borderLight, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("common.close".localized)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: downloadStory) {
                            Label("gallery.download".localized, systemImage: "arrow.down.circle")
                        }

                        Button(action: { Task { await prepareShare() } }) {
                            Label("common.share".localized, systemImage: "square.and.arrow.up")
                        }
                        .disabled(isPreparingShare)

                        Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                            Label("common.delete".localized, systemImage: "trash")
                        }
                        .tint(AppColors.errorRed)
                        .disabled(isDeleting)
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(AppColors.primaryBlue)
                            .frame(width: 36, height: 36)
                    }
                    .disabled(isPreparingShare || isDeleting)
                }
            }
            .toolbarBackground(AppColors.backgroundLight, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .overlay(alignment: .bottom) {
                audioPlayerControls
            }
            .onAppear {
                audioPlayer.loadAudio(from: story.audioUrl)
            }
            .onDisappear {
                audioPlayer.stop()
            }
            .alert("common.error".localized, isPresented: $showingErrorAlert) {
                Button("common.ok".localized) { }
            } message: {
                Text(errorMessage ?? "common.unknown.error".localized)
            }
            .alert("stories.delete.confirmation".localized, isPresented: $showingDeleteConfirmation) {
                Button("common.cancel".localized, role: .cancel) { }
                Button("common.delete".localized, role: .destructive) {
                    Task { await deleteStory() }
                }
            } message: {
                Text("stories.delete.confirmation.message".localized)
            }
            .sheet(isPresented: $showingShareSheet) {
                if let shareableAudioURL = shareableAudioURL {
                    ActivityViewController(activityItems: [shareableAudioURL])
                }
            }
        }
    }

    // MARK: - Unified Player View
    private var playerView: some View {
        VStack(spacing: 0) {
            // Header Section (Animated)
            if audioPlayer.isPlaying {
                compactHeaderView
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                expandedHeaderView
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Scrollable Content
            KaraokeTextView(
                storyText: story.storyText ?? "",
                currentWordIndex: audioPlayer.currentWordIndex,
                karaokeWords: audioPlayer.karaokeWords
            )
            .onAppear {
                if let storyText = story.storyText {
                    audioPlayer.prepareKaraokeSync(with: storyText)
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: audioPlayer.isPlaying)
    }
    
    // MARK: - Header Views
    
    private var expandedHeaderView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Top Row: Image + Title
            HStack(alignment: .top, spacing: AppSpacing.md) {
                // Cover Image
                AsyncImage(url: URL(string: story.imageUrl)) { imagePhase in
                    switch imagePhase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipped()
                            .cornerRadius(AppSizing.cornerRadius.md)
                    case .failure(_):
                        Rectangle()
                            .fill(Color(hex: "#6366F1").opacity(0.2))
                            .frame(width: 120, height: 120)
                            .cornerRadius(AppSizing.cornerRadius.md)
                            .overlay(
                                Image(systemName: "moon.stars")
                                    .font(.system(size: 30))
                                    .foregroundColor(Color(hex: "#6366F1"))
                            )
                    case .empty:
                        Rectangle()
                            .fill(AppColors.surfaceLight)
                            .frame(width: 120, height: 120)
                            .shimmer()
                            .cornerRadius(AppSizing.cornerRadius.md)
                    @unknown default:
                        EmptyView()
                    }
                }

                // Right Column: Title + Age Badge
                VStack(alignment: .leading, spacing: 8) {
                    Text(story.title)
                        .font(AppTypography.headlineSmall)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if let ageGroup = story.ageGroup {
                        StoryBadge(
                            icon: "figure.and.child.holdinghands",
                            text: ageGroup,
                            color: Color(hex: "#F59E0B") // Orange
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.lg)
            
            // Bottom Row: Scrollable Badges
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    StoryBadge(
                        icon: "clock.fill",
                        text: formatDuration(story.duration),
                        color: Color(hex: "#6366F1") // Indigo
                    )

                    if let voiceName = voiceName {
                        StoryBadge(
                            icon: "waveform",
                            text: voiceName,
                            color: Color(hex: "#EC4899") // Pink
                        )
                    }

                    if let theme = story.theme {
                        StoryBadge(
                            icon: "sparkles",
                            text: theme,
                            color: Color(hex: "#14B8A6") // Teal
                        )
                    }
                }
                .padding(.horizontal, AppSpacing.md)
            }
            
            Divider()
                .padding(.horizontal, AppSpacing.md)
        }
    }
    
    private var compactHeaderView: some View {
        HStack(spacing: AppSpacing.md) {
            // Tiny thumbnail
            AsyncImage(url: URL(string: story.imageUrl)) { imagePhase in
                if let image = imagePhase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Rectangle()
                        .fill(Color(hex: "#6366F1").opacity(0.2))
                        .frame(width: 48, height: 48)
                        .cornerRadius(8)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(story.title)
                    .font(AppTypography.titleMedium)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                
                Text(voiceName ?? "Story")
                    .font(AppTypography.captionLarge)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(AppColors.borderLight),
            alignment: .bottom
        )
    }

    // MARK: - Audio Player Controls
    private var audioPlayerControls: some View {
        VStack(spacing: AppSpacing.md) {
            // Seekable progress bar
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { audioPlayer.progress },
                        set: { newValue in
                            if !isSeeking {
                                isSeeking = true
                                // Haptic feedback when starting to seek
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
                            }
                            let newTime = newValue * audioPlayer.duration
                            audioPlayer.seek(to: newTime)
                        }
                    ),
                    in: 0...1,
                    onEditingChanged: { editing in
                        if !editing && isSeeking {
                            // Haptic feedback when releasing
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            isSeeking = false
                        }
                    }
                )
                .tint(Color(hex: "#6366F1"))
                .frame(height: 20) // Child-safe touch target

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

// MARK: - Share & Actions
private extension StoryPlayerView {
    func downloadStory() {
        guard let url = URL(string: story.audioUrl) else {
            presentError(StoryShareError.invalidURL)
            return
        }
        openURL(url)
    }

    func prepareShare() async {
        if await MainActor.run(body: { shareableAudioURL != nil }) {
            await MainActor.run { showingShareSheet = true }
            return
        }

        if await MainActor.run(body: { isPreparingShare }) {
            return
        }

        await MainActor.run { isPreparingShare = true }

        do {
            let fileURL = try await fetchAudioFile()
            await MainActor.run {
                shareableAudioURL = fileURL
                showingShareSheet = true
            }
        } catch {
            await MainActor.run {
                presentError(error)
            }
        }

        await MainActor.run { isPreparingShare = false }
    }

    func fetchAudioFile() async throws -> URL {
        guard let url = URL(string: story.audioUrl) else {
            throw StoryShareError.invalidURL
        }

        let (temporaryURL, response) = try await URLSession.shared.download(from: url)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw StoryShareError.failedRequest(status: httpResponse.statusCode)
        }

        let filename = makeSafeFilename(from: story.title)
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.copyItem(at: temporaryURL, to: destinationURL)
        return destinationURL
    }

    func deleteStory() async {
        if await MainActor.run(body: { isDeleting }) {
            return
        }

        await MainActor.run { isDeleting = true }

        do {
            try await BedtimeStoriesService.shared.deleteStory(id: story.id)

            await MainActor.run {
                audioPlayer.stop()
                isDeleting = false
                onStoryDeleted?(story.id)
                dismiss()
            }
        } catch {
            await MainActor.run {
                isDeleting = false
                presentError(error)
            }
        }
    }

    func makeSafeFilename(from title: String) -> String {
        let sanitized = title
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_")).inverted)
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        let baseName = sanitized.isEmpty ? "BedtimeStory" : sanitized
        return "\(baseName).mp3"
    }

    func presentError(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        showingErrorAlert = true
    }
}

private enum StoryShareError: LocalizedError {
    case invalidURL
    case failedRequest(status: Int)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "We couldn't access this story's audio file."
        case .failedRequest(let status):
            return "Audio download failed (status code: \(status)). Please try again."
        case .invalidData:
            return "The audio file is corrupted. Please try again."
        }
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
    @Published var karaokeWords: [KaraokeWord] = []

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

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            #if DEBUG
            print("🎧 AVAudioSession configured for background playback.")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to set up AVAudioSession for background playback: \(error)")
            #endif
        }
    }

    func loadAudio(from urlString: String) {
        setupAudioSession()

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
        let timer = Timer(timeInterval: 0.0167, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateCurrentWord()
            }
        }
        updateTimer = timer
        RunLoop.current.add(timer, forMode: .common)

        #if DEBUG
        print("⚡ Lyrics sync started: 60fps (16.67ms intervals) in common run loop mode")
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

// MARK: - Custom Audio Slider Style
struct AudioSliderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .accentColor(Color(hex: "#6366F1"))
    }
}

// MARK: - Karaoke Text View
/// Enhanced karaoke-style text view with word-by-word highlighting
/// Matches web implementation with larger text, scaling animations, and blur effects
struct KaraokeTextView: View {
    let storyText: String
    let currentWordIndex: Int
    let karaokeWords: [KaraokeWord]

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    // Render text by paragraphs to maintain line breaks
                    ForEach(paragraphs, id: \.offset) { paragraph in
                        WordFlowLayout(spacing: 8) {
                            renderParagraph(paragraph)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, 200) // Ensure last words clear the player controls
            }
            .onChange(of: currentWordIndex) { _, newIndex in
                // Auto-scroll to active word (centered slightly higher)
                if newIndex >= 0 && newIndex < karaokeWords.count {
                    let wordID = karaokeWords[newIndex].id

                    withAnimation(.easeInOut(duration: 0.3)) {
                        scrollProxy.scrollTo(wordID, anchor: UnitPoint(x: 0.5, y: 0.4))
                    }
                }
            }
        }
    }

    /// Split text into paragraphs
    private var paragraphs: [(offset: Int, text: String)] {
        storyText.components(separatedBy: "\n")
            .enumerated()
            .map { ($0.offset, $0.element) }
    }

    /// Render a paragraph with word-by-word highlighting
    @ViewBuilder
    private func renderParagraph(_ paragraph: (offset: Int, text: String)) -> some View {
        let words = paragraph.text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let startIndex = calculateStartIndex(for: paragraph.offset)

        ForEach(Array(words.enumerated()), id: \.offset) { wordOffset, word in
            let globalWordIndex = startIndex + wordOffset
            renderWord(word, at: globalWordIndex)
        }
    }

    /// Render a single word with karaoke styling
    @ViewBuilder
    private func renderWord(_ word: String, at index: Int) -> some View {
        let isCurrentWord = index == currentWordIndex

        Text(word)
            .font(AppTypography.displayMedium) // 36pt - much larger!
            .fontWeight(.bold)
            .foregroundColor(isCurrentWord ? Color(hex: "#6366F1") : Color.gray.opacity(0.35))
            .scaleEffect(isCurrentWord ? 1.1 : 1.0) // Scale up active word
            .blur(radius: isCurrentWord ? 0 : 0.3) // Slight blur for inactive words
            .animation(.easeInOut(duration: 0.2), value: currentWordIndex)
            .id(index < karaokeWords.count ? karaokeWords[index].id : UUID())
    }

    /// Calculate starting word index for a paragraph
    private func calculateStartIndex(for paragraphIndex: Int) -> Int {
        var index = 0
        let paragraphTexts = storyText.components(separatedBy: "\n")

        for i in 0..<min(paragraphIndex, paragraphTexts.count) {
            let words = paragraphTexts[i].components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            index += words.count
        }

        return index
    }
}

// MARK: - Word Flow Layout
/// Custom layout that flows words like text, wrapping at line boundaries
struct WordFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.width ?? 0,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    // Move to next line
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - Story Badge Component
struct StoryBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(AppTypography.captionLarge)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .foregroundColor(color)
        .clipShape(Capsule())
    }
}
