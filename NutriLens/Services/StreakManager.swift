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

    /// Check goals met using pre-aggregated daily totals (O(1) per day)
    private static func goalsMetForDay(
        dayTotals: (cal: Double, protein: Double, carbs: Double, fat: Double),
        goal: DailyGoal
    ) -> Bool {
        guard dayTotals.cal > 0 else { return false }
        return isOnTarget(dayTotals.cal, target: goal.calorieTarget)
            && isOnTarget(dayTotals.protein, target: goal.proteinGramsTarget)
            && isOnTarget(dayTotals.carbs, target: goal.carbsGramsTarget)
            && isOnTarget(dayTotals.fat, target: goal.fatGramsTarget)
    }

    /// Pre-group meals by day — O(n) single pass instead of O(n*m) repeated filtering
    private static func groupMealsByDay(_ meals: [Meal]) -> [Date: (cal: Double, protein: Double, carbs: Double, fat: Double)] {
        let calendar = Calendar.current
        var grouped: [Date: (cal: Double, protein: Double, carbs: Double, fat: Double)] = [:]
        for meal in meals {
            let dayStart = calendar.startOfDay(for: meal.timestamp)
            let existing = grouped[dayStart] ?? (0, 0, 0, 0)
            grouped[dayStart] = (
                existing.cal + meal.totalCalories,
                existing.protein + meal.totalProteinGrams,
                existing.carbs + meal.totalCarbsGrams,
                existing.fat + meal.totalFatGrams
            )
        }
        return grouped
    }

    /// Backward-compatible single-day check
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

    /// Compute current streak length using O(n) pre-grouping
    static func currentStreakLength(meals: [Meal], goal: DailyGoal) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let grouped = groupMealsByDay(meals)
        var streak = 0
        guard var checkDate = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }

        for _ in 0..<365 {
            let totals = grouped[checkDate] ?? (0, 0, 0, 0)
            guard goalsMetForDay(dayTotals: totals, goal: goal) else { break }
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }

    /// Compute longest streak ever using O(n) pre-grouping
    static func longestStreak(meals: [Meal], goal: DailyGoal) -> Int {
        guard let earliest = meals.map(\.timestamp).min() else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let grouped = groupMealsByDay(meals)
        var date = calendar.startOfDay(for: earliest)
        var longest = 0
        var current = 0

        while date < today {
            let totals = grouped[date] ?? (0, 0, 0, 0)
            if goalsMetForDay(dayTotals: totals, goal: goal) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return longest
    }
}
