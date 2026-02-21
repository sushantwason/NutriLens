import Foundation

@Observable
final class TrialManager {
    // MARK: - Constants

    static let trialDurationDays = 3

    // MARK: - State

    private(set) var firstLaunchDate: Date

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let firstLaunchDate = "nutrilens.trial.firstLaunchDate"
    }

    init() {
        let now = Date()
        let storedTimestamp = UserDefaults.standard.double(forKey: Keys.firstLaunchDate)
        if storedTimestamp > 0 {
            let storedDate = Date(timeIntervalSince1970: storedTimestamp)
            // Validate: stored date should not be in the future (clock manipulation)
            if storedDate > now {
                // Reset to now — treat as new trial start
                self.firstLaunchDate = now
                UserDefaults.standard.set(now.timeIntervalSince1970, forKey: Keys.firstLaunchDate)
            } else {
                self.firstLaunchDate = storedDate
            }
        } else {
            // New user — record first launch now
            self.firstLaunchDate = now
            UserDefaults.standard.set(now.timeIntervalSince1970, forKey: Keys.firstLaunchDate)
        }
    }

    /// Date when the trial expires
    var trialExpirationDate: Date {
        Calendar.current.date(
            byAdding: .day,
            value: Self.trialDurationDays,
            to: firstLaunchDate
        ) ?? firstLaunchDate
    }

    /// Whether the trial period is still active
    var isTrialActive: Bool {
        Date() < trialExpirationDate
    }

    /// Number of full days remaining in the trial (0 if expired)
    var trialDaysRemaining: Int {
        let components = Calendar.current.dateComponents([.day], from: Date(), to: trialExpirationDate)
        return max(0, (components.day ?? 0))
    }

    /// Whether the user can access scanning features
    /// Returns true if: owner bypass, Pro subscriber, or trial still active
    func canAccess(isPro: Bool) -> Bool {
        if OwnerBypass.isOwnerDevice { return true }
        if isPro { return true }
        return isTrialActive
    }
}
