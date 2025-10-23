import Foundation

/// Utility for detecting device language preferences
struct DeviceLanguage {

    /// Detects the device's preferred language and returns a supported language code
    /// - Returns: "en" for English, "es" for Spanish
    static func getPreferredLanguage() -> String {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"

        #if DEBUG
        print("🌍 Device Language Detection:")
        print("   - Preferred language: \(preferredLanguage)")
        print("   - All preferred languages: \(Locale.preferredLanguages)")
        #endif

        // Extract language code (e.g., "es-MX" → "es", "en-US" → "en")
        if preferredLanguage.hasPrefix("es") {
            #if DEBUG
            print("   - Detected: Spanish (es)")
            #endif
            return "es"
        } else {
            #if DEBUG
            print("   - Detected: English (en)")
            #endif
            return "en"
        }
    }

    /// Get localized display name for a language code
    /// - Parameter code: Language code ("en" or "es")
    /// - Returns: Localized language name (e.g., "English", "Español")
    static func displayName(for code: String) -> String {
        switch code {
        case "es":
            return "Español"
        case "en":
            return "English"
        default:
            return "English"
        }
    }

    /// Check if a language code is supported
    /// - Parameter code: Language code to validate
    /// - Returns: True if supported, false otherwise
    static func isSupported(_ code: String) -> Bool {
        return code == "en" || code == "es"
    }
}
