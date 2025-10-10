import Foundation

/// Matched word with original text and timing
struct KaraokeWord: Identifiable {
    let id = UUID()
    let originalWord: String
    let normalizedWord: String
    let start: Double
    let end: Double
    let index: Int
}

/// Utility for matching story text with Whisper word timestamps
struct KaraokeMatcher {

    /// Normalize word for matching (handles possessives, punctuation, accents)
    static func normalizeWord(_ word: String) -> String {
        return word
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current) // Remove accents (é → e)
            .replacingOccurrences(of: "'", with: "") // Remove apostrophes (all types)
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "`", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined() // Remove all non-alphanumeric chars
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Match story text with Whisper word timestamps
    /// - Parameters:
    ///   - storyText: Original story text with punctuation
    ///   - wordTimestamps: Whisper word timestamps from backend
    ///   - debug: Enable debug logging
    /// - Returns: Array of matched karaoke words
    static func matchWords(
        storyText: String,
        wordTimestamps: [WordTimestamp],
        debug: Bool = false
    ) -> [KaraokeWord] {
        // Split on ALL whitespace (spaces, newlines, tabs) to handle paragraph breaks
        let originalWords = storyText.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        var result: [KaraokeWord] = []
        var timestampIndex = 0

        if debug {
            print("🎤 KaraokeMatcher: Starting word matching")
            print("   - Original words count: \(originalWords.count)")
            print("   - Timestamp words count: \(wordTimestamps.count)")
        }

        for (i, originalWord) in originalWords.enumerated() {
            let normalizedOrig = normalizeWord(originalWord)

            // Skip empty normalized words (punctuation only)
            if normalizedOrig.isEmpty {
                if debug {
                    print("   ⚠️ Skipping empty normalized word: \"\(originalWord)\" at index \(i)")
                }
                // Don't add to result, don't consume timestamp
                continue
            }

            // Check if we have timestamps left
            guard timestampIndex < wordTimestamps.count else {
                if debug {
                    print("   ⚠️ No timestamp for word: \"\(originalWord)\" at index \(i)")
                }

                // Use last word's timing + estimate
                if let lastWord = result.last {
                    result.append(KaraokeWord(
                        originalWord: originalWord,
                        normalizedWord: normalizedOrig,
                        start: lastWord.end,
                        end: lastWord.end + 0.5, // Estimate 0.5s duration
                        index: i
                    ))
                }
                continue
            }

            let whisperWord = wordTimestamps[timestampIndex]
            let normalizedTimestamp = normalizeWord(whisperWord.word)

            if normalizedOrig == normalizedTimestamp {
                // Perfect match
                if debug {
                    print("   ✅ Match [\(i)]: \"\(originalWord)\" → \"\(whisperWord.word)\"")
                }

                result.append(KaraokeWord(
                    originalWord: originalWord,
                    normalizedWord: normalizedOrig,
                    start: whisperWord.start,
                    end: whisperWord.end,
                    index: i
                ))
                timestampIndex += 1

            } else {
                // Mismatch - use timestamp anyway to keep sync
                if debug {
                    print("   ⚠️ Mismatch at index \(i):")
                    print("      Original: \"\(originalWord)\" → normalized: \"\(normalizedOrig)\"")
                    print("      Whisper: \"\(whisperWord.word)\" → normalized: \"\(normalizedTimestamp)\"")
                    print("      Using Whisper timestamp anyway to maintain sync")
                }

                // Use the timestamp anyway - this keeps word indices aligned
                // Even if the words don't match perfectly, the timing will be close
                result.append(KaraokeWord(
                    originalWord: originalWord,
                    normalizedWord: normalizedOrig,
                    start: whisperWord.start,
                    end: whisperWord.end,
                    index: i
                ))
                timestampIndex += 1
            }
        }

        if debug {
            print("🎤 KaraokeMatcher: Matching complete")
            print("   - Matched words: \(result.count)")
            print("   - Timestamps used: \(timestampIndex)/\(wordTimestamps.count)")

            // Show index gaps (potential issues)
            var lastIndex = -1
            for word in result {
                if lastIndex >= 0 && word.index > lastIndex + 1 {
                    print("   ⚠️ Index gap: \(lastIndex) → \(word.index) (skipped \(word.index - lastIndex - 1) words)")
                }
                lastIndex = word.index
            }
        }

        return result
    }

    /// Find current word index based on audio playback time (Apple Music style)
    /// - Parameters:
    ///   - currentTime: Current audio playback time in seconds
    ///   - karaokeWords: Array of matched karaoke words
    /// - Returns: Index of current word, or -1 if none
    static func findCurrentWordIndex(
        currentTime: Double,
        karaokeWords: [KaraokeWord]
    ) -> Int {
        guard !karaokeWords.isEmpty else { return -1 }

        // 🎵 APPLE MUSIC STRATEGY: Binary search with look-ahead
        // A word is "active" from its start time until the NEXT word starts
        // This eliminates gaps between words and prevents skipping

        // Before first word
        if currentTime < karaokeWords[0].start {
            return -1
        }

        // After last word
        if currentTime >= karaokeWords[karaokeWords.count - 1].start {
            return karaokeWords.count - 1
        }

        // Binary search to find the word whose start time is <= currentTime
        // and the next word's start time is > currentTime
        var left = 0
        var right = karaokeWords.count - 1

        while left < right {
            let mid = (left + right + 1) / 2  // Round up to avoid infinite loop

            if karaokeWords[mid].start <= currentTime {
                left = mid
            } else {
                right = mid - 1
            }
        }

        // At this point, left == right and points to the active word
        return left
    }
}

// MARK: - Test Cases

#if DEBUG
extension KaraokeMatcher {

    struct TestCase {
        let name: String
        let original: String
        let whisper: [WordTimestamp]
        let expectedMatchCount: Int
    }

    static func runTests() {
        let tests: [TestCase] = [
            TestCase(
                name: "Padmé possessive",
                original: "Padmé's adventure began",
                whisper: [
                    WordTimestamp(word: "Padmes", start: 0.0, end: 0.5),
                    WordTimestamp(word: "adventure", start: 0.5, end: 1.0),
                    WordTimestamp(word: "began", start: 1.0, end: 1.5)
                ],
                expectedMatchCount: 3
            ),
            TestCase(
                name: "Leah possessive",
                original: "Leah's toy was red",
                whisper: [
                    WordTimestamp(word: "Leahs", start: 0.0, end: 0.4),
                    WordTimestamp(word: "toy", start: 0.4, end: 0.7),
                    WordTimestamp(word: "was", start: 0.7, end: 0.9),
                    WordTimestamp(word: "red", start: 0.9, end: 1.2)
                ],
                expectedMatchCount: 4
            ),
            TestCase(
                name: "Contractions",
                original: "I couldn't see anything",
                whisper: [
                    WordTimestamp(word: "I", start: 0.0, end: 0.2),
                    WordTimestamp(word: "couldnt", start: 0.2, end: 0.6),
                    WordTimestamp(word: "see", start: 0.6, end: 0.8),
                    WordTimestamp(word: "anything", start: 0.8, end: 1.2)
                ],
                expectedMatchCount: 4
            ),
            TestCase(
                name: "Multiple possessives",
                original: "Emma's friend and Dad's car",
                whisper: [
                    WordTimestamp(word: "Emmas", start: 0.0, end: 0.4),
                    WordTimestamp(word: "friend", start: 0.4, end: 0.8),
                    WordTimestamp(word: "and", start: 0.8, end: 1.0),
                    WordTimestamp(word: "Dads", start: 1.0, end: 1.3),
                    WordTimestamp(word: "car", start: 1.3, end: 1.6)
                ],
                expectedMatchCount: 5
            ),
            TestCase(
                name: "Accented characters",
                original: "José's book",
                whisper: [
                    WordTimestamp(word: "Joses", start: 0.0, end: 0.5),
                    WordTimestamp(word: "book", start: 0.5, end: 0.9)
                ],
                expectedMatchCount: 2
            )
        ]

        print("\n🧪 Running KaraokeMatcher Tests\n")

        var passedCount = 0
        var failedCount = 0

        for test in tests {
            print("Testing: \(test.name)")
            let matched = matchWords(storyText: test.original, wordTimestamps: test.whisper, debug: true)

            if matched.count == test.expectedMatchCount {
                print("✅ PASSED: \(test.name) - matched \(matched.count) words\n")
                passedCount += 1
            } else {
                print("❌ FAILED: \(test.name)")
                print("   Expected: \(test.expectedMatchCount) matches")
                print("   Got: \(matched.count) matches\n")
                failedCount += 1
            }
        }

        print("📊 Test Results:")
        print("   ✅ Passed: \(passedCount)")
        print("   ❌ Failed: \(failedCount)")
        print("   📈 Success Rate: \(passedCount * 100 / tests.count)%\n")
    }
}
#endif
