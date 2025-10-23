//
//  LocalizationManager.swift
//  SketchWink
//
//  Manages app localization and language switching
//

import Foundation
import SwiftUI
import Combine

/// Supported languages in the app
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es"

    var id: String { rawValue }

    /// Display name for the language
    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .spanish:
            return "Español"
        }
    }

    /// Flag emoji for the language
    var flag: String {
        switch self {
        case .english:
            return "🇺🇸"
        case .spanish:
            return "🇪🇸"
        }
    }
}

/// Manages app localization and provides localized strings
class LocalizationManager: ObservableObject {

    // MARK: - Singleton
    static let shared = LocalizationManager()

    // MARK: - Published Properties
    @Published var currentLanguage: AppLanguage {
        didSet {
            saveLanguagePreference()
            // Post notification to update UI
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
        }
    }

    // MARK: - Private Properties
    private let languageKey = "app_language_preference"

    // MARK: - Initialization
    private init() {
        // Load saved language preference or use device language detection
        if let savedLanguageCode = UserDefaults.standard.string(forKey: languageKey),
           let savedLanguage = AppLanguage(rawValue: savedLanguageCode) {
            self.currentLanguage = savedLanguage
            #if DEBUG
            print("🌍 LocalizationManager: Loaded saved language: \(savedLanguage.displayName)")
            #endif
        } else {
            // Use device language detection on first launch
            let detectedLanguage = DeviceLanguage.getPreferredLanguage()
            self.currentLanguage = AppLanguage(rawValue: detectedLanguage) ?? .english
            #if DEBUG
            print("🌍 LocalizationManager: Auto-detected device language: \(self.currentLanguage.displayName)")
            #endif
        }
    }

    // MARK: - Public Methods

    /// Change the app language
    /// - Parameter language: The new language to use
    func changeLanguage(to language: AppLanguage) {
        currentLanguage = language
    }

    /// Get localized string for a key
    /// - Parameters:
    ///   - key: The localization key
    ///   - arguments: Optional arguments for string formatting
    /// - Returns: Localized string
    func localizedString(_ key: String, arguments: CVarArg...) -> String {
        guard let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(key, comment: "")
        }

        let localizedString = NSLocalizedString(key, bundle: bundle, comment: "")

        if arguments.isEmpty {
            return localizedString
        } else {
            return String(format: localizedString, arguments: arguments)
        }
    }

    // MARK: - Private Methods

    private func saveLanguagePreference() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: languageKey)
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

// MARK: - String Extension for Easy Localization
extension String {
    /// Returns the localized version of the string using LocalizationManager
    var localized: String {
        LocalizationManager.shared.localizedString(self)
    }

    /// Returns the localized version of the string with arguments
    /// - Parameter arguments: Arguments for string formatting
    /// - Returns: Formatted localized string
    func localized(with arguments: CVarArg...) -> String {
        LocalizationManager.shared.localizedString(self, arguments: arguments)
    }
}
