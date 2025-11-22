import Foundation

/// Session cache for storing and checking session expiry without API calls
/// Works with any authentication system (Better Auth, JWT, etc.)
class SessionCache {

    // MARK: - Constants
    private static let expiryKey = "session_expiry_date"
    private static let lastValidationKey = "session_last_validation"
    
    // MARK: - Formatters
    private static let isoFormatterWithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    private static func parseISODate(_ isoString: String) -> Date? {
        if let date = isoFormatterWithFractional.date(from: isoString) {
            return date
        }
        return isoFormatter.date(from: isoString)
    }

    // MARK: - Cache Session Expiry

    /// Cache the session expiry date from backend response
    /// - Parameter expiresAt: ISO8601 date string from backend (e.g., "2025-12-22T20:07:51.000Z")
    static func cacheExpiry(_ expiresAt: String) {
        guard let expiryDate = parseISODate(expiresAt) else {
            #if DEBUG
            print("❌ SessionCache: Failed to parse expiry string '\(expiresAt)'")
            #endif
            UserDefaults.standard.removeObject(forKey: expiryKey)
            return
        }
        
        UserDefaults.standard.set(expiryDate, forKey: expiryKey)
        UserDefaults.standard.set(Date(), forKey: lastValidationKey)

        // Force synchronize to disk immediately to ensure persistence
        UserDefaults.standard.synchronize()

        #if DEBUG
        if let expiry = getExpiry() {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            print("💾 SessionCache: Cached expiry - \(formatter.string(from: expiry))")

            let daysRemaining = Int(expiry.timeIntervalSinceNow / (24 * 60 * 60))
            print("💾 SessionCache: \(daysRemaining) days remaining")
        }

        // Verify it was actually saved
        if hasCachedExpiry() {
            print("✅ SessionCache: Expiry successfully persisted to UserDefaults")
        } else {
            print("❌ SessionCache: WARNING - Failed to persist expiry to UserDefaults!")
        }
        #endif
    }

    /// Get the cached expiry date
    /// - Returns: Expiry date or nil if not cached
    static func getExpiry() -> Date? {
        if let storedDate = UserDefaults.standard.object(forKey: expiryKey) as? Date {
            return storedDate
        }
        
        // Support legacy string storage by migrating it to Date
        if let expiryString = UserDefaults.standard.string(forKey: expiryKey),
           let parsedDate = parseISODate(expiryString) {
            UserDefaults.standard.set(parsedDate, forKey: expiryKey)
            return parsedDate
        }
        
        return nil
    }

    // MARK: - Expiry Checks

    /// Check if cached session is expired
    /// - Returns: True if expired or no cache exists
    static func isExpired() -> Bool {
        guard let expiry = getExpiry() else {
            #if DEBUG
            print("⚠️ SessionCache: No cached expiry, assuming expired")
            #endif
            return true
        }

        let expired = Date() >= expiry

        #if DEBUG
        if expired {
            print("❌ SessionCache: Session expired locally")
        }
        #endif

        return expired
    }

    /// Check if session is expiring soon (within specified days)
    /// - Parameter days: Number of days to check (default: 7)
    /// - Returns: True if expiring within specified days or no cache exists
    static func isExpiringSoon(withinDays days: Int = 7) -> Bool {
        guard let expiry = getExpiry() else {
            #if DEBUG
            print("⚠️ SessionCache: No cached expiry, validation required")
            #endif
            return true
        }

        let daysInSeconds = TimeInterval(days * 24 * 60 * 60)
        let expiringThreshold = expiry.addingTimeInterval(-daysInSeconds)
        let expiringSoon = Date() >= expiringThreshold

        #if DEBUG
        if expiringSoon {
            let daysRemaining = Int(expiry.timeIntervalSinceNow / (24 * 60 * 60))
            print("⚠️ SessionCache: Session expiring soon (\(daysRemaining) days left), validation required")
        } else {
            let daysRemaining = Int(expiry.timeIntervalSinceNow / (24 * 60 * 60))
            print("✅ SessionCache: Session valid for \(daysRemaining) more days, skipping validation")
        }
        #endif

        return expiringSoon
    }

    /// Get time remaining until expiry
    /// - Returns: Time interval in seconds, or nil if no cache
    static func timeUntilExpiry() -> TimeInterval? {
        guard let expiry = getExpiry() else { return nil }
        return expiry.timeIntervalSinceNow
    }

    /// Get days remaining until expiry
    /// - Returns: Number of days, or nil if no cache
    static func daysUntilExpiry() -> Int? {
        guard let timeInterval = timeUntilExpiry() else { return nil }
        return Int(timeInterval / (24 * 60 * 60))
    }

    // MARK: - Cache Management

    /// Clear all cached session data
    static func clearCache() {
        UserDefaults.standard.removeObject(forKey: expiryKey)
        UserDefaults.standard.removeObject(forKey: lastValidationKey)

        #if DEBUG
        print("🗑️ SessionCache: Cache cleared")
        #endif
    }

    /// Check if cache exists
    /// - Returns: True if expiry is cached
    static func hasCachedExpiry() -> Bool {
        return UserDefaults.standard.object(forKey: expiryKey) != nil
    }

    /// Get last validation time
    /// - Returns: Date of last validation or nil
    static func getLastValidation() -> Date? {
        return UserDefaults.standard.object(forKey: lastValidationKey) as? Date
    }
}
