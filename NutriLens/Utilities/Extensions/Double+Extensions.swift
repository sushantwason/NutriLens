import Foundation

extension Double {
    /// Format as "123" (no decimals) for calories
    var calorieString: String {
        String(format: "%.0f", self)
    }

    /// Format as "12.5g" for grams
    var gramString: String {
        String(format: "%.1fg", self)
    }

    /// Format as "12.5" with one decimal
    var oneDecimalString: String {
        String(format: "%.1f", self)
    }

    /// Format as "1500" (no decimals) for milliliters
    var mlString: String {
        String(format: "%.0f", self)
    }

    /// Percentage of a target, clamped to 0...1
    func progressRatio(of target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(self / target, 1.0)
    }
}
