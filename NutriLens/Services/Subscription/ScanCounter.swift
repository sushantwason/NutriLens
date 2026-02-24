import Foundation

@MainActor @Observable
final class ScanCounter {
    // MARK: - State

    private(set) var monthlyCount: Int = 0
    private(set) var monthKey: String = ""

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
        case .pro:
            return true
        case .none:
            return false
        }
    }

    // MARK: - Private

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()

    private func loadCurrentMonth() {
        let currentMonth = Self.monthFormatter.string(from: Date())

        let persistedMonthKey = UserDefaults.standard.string(forKey: Self.monthKeyKey) ?? ""

        if persistedMonthKey == currentMonth {
            monthKey = currentMonth
            monthlyCount = UserDefaults.standard.integer(forKey: Self.countKey(for: currentMonth))
        } else {
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
