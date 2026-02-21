import Foundation

enum StreakManager {
    /// Tolerance for "on target" (10% over or under)
    static let tolerance: Double = 0.10

    /// Check if a value is within tolerance of a target
    static func isOnTarget(_ actual: Double, target: Double) -> Bool {
        guard target > 0 else { return true }
        let ratio = actual / target
        return ratio >= (1.0 - tolerance) && ratio <= (1.0 + tolerance)
    }

    /// Compute whether all goals were met for a given day
    static func goalsMetForDay(
        meals: [Meal],
        goal: DailyGoal,
        date: Date
    ) -> Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return false }

        let dayMeals = meals.filter { $0.timestamp >= dayStart && $0.timestamp < dayEnd }
        guard !dayMeals.isEmpty else { return false }

        let totalCal = dayMeals.reduce(0.0) { $0 + $1.totalCalories }
        let totalProtein = dayMeals.reduce(0.0) { $0 + $1.totalProteinGrams }
        let totalCarbs = dayMeals.reduce(0.0) { $0 + $1.totalCarbsGrams }
        let totalFat = dayMeals.reduce(0.0) { $0 + $1.totalFatGrams }

        return isOnTarget(totalCal, target: goal.calorieTarget)
            && isOnTarget(totalProtein, target: goal.proteinGramsTarget)
            && isOnTarget(totalCarbs, target: goal.carbsGramsTarget)
            && isOnTarget(totalFat, target: goal.fatGramsTarget)
    }

    /// Compute current streak length (consecutive days where all goals met,
    /// counting backwards from yesterday). Today is excluded because the day is incomplete.
    static func currentStreakLength(meals: [Meal], goal: DailyGoal) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var checkDate = calendar.date(byAdding: .day, value: -1, to: today)!

        // Limit lookback to 365 days for performance
        for _ in 0..<365 {
            guard goalsMetForDay(meals: meals, goal: goal, date: checkDate) else { break }
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
        }

        return streak
    }

    /// Compute longest streak ever
    static func longestStreak(meals: [Meal], goal: DailyGoal) -> Int {
        guard let earliest = meals.map(\.timestamp).min() else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var date = calendar.startOfDay(for: earliest)
        var longest = 0
        var current = 0

        while date < today {
            if goalsMetForDay(meals: meals, goal: goal, date: date) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }

        return longest
    }
}
