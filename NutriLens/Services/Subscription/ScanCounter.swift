import Foundation

@Observable
final class ScanCounter {
    // MARK: - State

    private(set) var monthlyCount: Int = 0
    private(set) var monthKey: String = ""

    // MARK: - Constants

    static let standardMonthlyLimit = 100

    // MARK: - Keys

    private static let monthKeyKey = "nutrilens.scans.monthKey"
    private static func countKey(for month: String) -> String {
        "nutrilens.scans.\(month)"
    }

    // MARK: - Init

    init() {
        loadCurrentMonth()
    }

    // MARK: - Public

    /// Record a scan. Call after a successful scan completes.
    func recordScan() {
        loadCurrentMonth() // Ensure month is current
        monthlyCount += 1
        persist()
    }

    /// Whether the user can scan given their subscription tier.
    func canScan(tier: SubscriptionTier) -> Bool {
        switch tier {
        case .unlimited:
            return true
        case .standard:
            loadCurrentMonth()
            return monthlyCount < Self.standardMonthlyLimit
        case .none:
            return false
        }
    }

    /// Remaining scans for Standard tier.
    var remainingScans: Int {
        max(0, Self.standardMonthlyLimit - monthlyCount)
    }

    // MARK: - Private

    private func loadCurrentMonth() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        let currentMonth = formatter.string(from: Date())

        // First, load the persisted month key to see if we already have data
        let persistedMonthKey = UserDefaults.standard.string(forKey: Self.monthKeyKey) ?? ""

        if persistedMonthKey == currentMonth {
            // Same month as persisted — load the saved count
            monthKey = currentMonth
            monthlyCount = UserDefaults.standard.integer(forKey: Self.countKey(for: currentMonth))
        } else {
            // New month (or first launch) — reset counter
            monthKey = currentMonth
            monthlyCount = 0
            persist()
        }
    }

    private func persist() {
        UserDefaults.standard.set(monthKey, forKey: Self.monthKeyKey)
        UserDefaults.standard.set(monthlyCount, forKey: Self.countKey(for: monthKey))
    }
}
