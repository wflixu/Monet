import Foundation

enum UsageTracker {
    private enum Key {
        static let firstLaunchDate = "usage_firstLaunchDate"
        static let openCount = "usage_openCount"
        static let lastPromptDate = "usage_lastPromptDate"
        static let lastPromptOpenCount = "usage_lastPromptOpenCount"
        static let hasPurchased = "usage_hasPurchased"
        static let purchasedProductID = "usage_purchasedProductID"
        static let lastAppVersion = "usage_lastAppVersion"
    }

    private static var defaults: UserDefaults { .standard }

    static var firstLaunchDate: Date? {
        let timestamp = defaults.double(forKey: Key.firstLaunchDate)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    static var openCount: Int {
        defaults.integer(forKey: Key.openCount)
    }

    static var lastPromptDate: Date? {
        let timestamp = defaults.double(forKey: Key.lastPromptDate)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    static var lastPromptOpenCount: Int {
        defaults.integer(forKey: Key.lastPromptOpenCount)
    }

    static var hasPurchased: Bool {
        get { defaults.bool(forKey: Key.hasPurchased) }
        set { defaults.set(newValue, forKey: Key.hasPurchased) }
    }

    static var purchasedProductID: String? {
        get { defaults.string(forKey: Key.purchasedProductID) }
        set { defaults.set(newValue, forKey: Key.purchasedProductID) }
    }

    // MARK: - Actions

    static func recordLaunch(currentVersion: String = "") {
        // Detect app upgrade/reinstall — reset prompt counters so new install
        // doesn't immediately show the purchase prompt from old UserDefaults data.
        let lastVersion = defaults.string(forKey: Key.lastAppVersion)
        if let lastVersion, lastVersion != currentVersion {
            defaults.removeObject(forKey: Key.firstLaunchDate)
            defaults.removeObject(forKey: Key.openCount)
            defaults.removeObject(forKey: Key.lastPromptDate)
            defaults.removeObject(forKey: Key.lastPromptOpenCount)
        }
        defaults.set(currentVersion, forKey: Key.lastAppVersion)

        let count = defaults.integer(forKey: Key.openCount) + 1
        defaults.set(count, forKey: Key.openCount)

        if defaults.double(forKey: Key.firstLaunchDate) == 0 {
            defaults.set(Date().timeIntervalSince1970, forKey: Key.firstLaunchDate)
        }
    }

    static func recordPrompt() {
        defaults.set(Date().timeIntervalSince1970, forKey: Key.lastPromptDate)
        defaults.set(defaults.integer(forKey: Key.openCount), forKey: Key.lastPromptOpenCount)
    }

    // MARK: - Logic

    static func shouldShowPrompt() -> Bool {
        if hasPurchased { return false }
        guard let firstLaunch = firstLaunchDate else { return false }

        let now = Date()
        let count = openCount

        let isFirstPrompt = lastPromptDate == nil

        if isFirstPrompt {
            let daysSinceFirst = now.timeIntervalSince(firstLaunch) / (24 * 3600)
            return count >= 15 && daysSinceFirst >= 7
        } else {
            guard let lastDate = lastPromptDate else { return false }
            let daysSinceLast = now.timeIntervalSince(lastDate) / (24 * 3600)
            let countSinceLast = count - lastPromptOpenCount
            return countSinceLast >= 10 && daysSinceLast >= 5
        }
    }

#if DEBUG
    static func resetAll() {
        defaults.removeObject(forKey: Key.firstLaunchDate)
        defaults.removeObject(forKey: Key.openCount)
        defaults.removeObject(forKey: Key.lastPromptDate)
        defaults.removeObject(forKey: Key.lastPromptOpenCount)
        defaults.removeObject(forKey: Key.hasPurchased)
        defaults.removeObject(forKey: Key.purchasedProductID)
    }

    static func forceReadyForPrompt() {
        let now = Date()
        defaults.set(now.timeIntervalSince1970 - 8 * 24 * 3600, forKey: Key.firstLaunchDate)
        defaults.set(15, forKey: Key.openCount)
        defaults.removeObject(forKey: Key.lastPromptDate)
        defaults.removeObject(forKey: Key.lastPromptOpenCount)
    }
#endif
}

extension Notification.Name {
    static let showPurchasePrompt = Notification.Name("showPurchasePrompt")
}
