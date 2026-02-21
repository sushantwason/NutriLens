import Foundation

struct WeeklyReport {
    let weekStart: Date
    let weekEnd: Date
    let dailySummaries: [NutritionCalculator.DailySummary]
    let totalMeals: Int
    let activeDays: Int

    var avgCalories: Double {
        guard activeDays > 0 else { return 0 }
        return dailySummaries.reduce(0) { $0 + $1.totalCalories } / Double(activeDays)
    }

    var avgProtein: Double {
        guard activeDays > 0 else { return 0 }
        return dailySummaries.reduce(0) { $0 + $1.totalProtein } / Double(activeDays)
    }

    var avgCarbs: Double {
        guard activeDays > 0 else { return 0 }
        return dailySummaries.reduce(0) { $0 + $1.totalCarbs } / Double(activeDays)
    }

    var avgFat: Double {
        guard activeDays > 0 else { return 0 }
        return dailySummaries.reduce(0) { $0 + $1.totalFat } / Double(activeDays)
    }

    var highestCalorieDay: NutritionCalculator.DailySummary? {
        dailySummaries.filter { $0.mealCount > 0 }.max(by: { $0.totalCalories < $1.totalCalories })
    }

    var lowestCalorieDay: NutritionCalculator.DailySummary? {
        dailySummaries.filter { $0.mealCount > 0 }.min(by: { $0.totalCalories < $1.totalCalories })
    }
}

struct WeekComparison {
    let currentWeek: WeeklyReport
    let previousWeek: WeeklyReport

    var calorieChange: Double {
        percentChange(current: currentWeek.avgCalories, previous: previousWeek.avgCalories)
    }

    var proteinChange: Double {
        percentChange(current: currentWeek.avgProtein, previous: previousWeek.avgProtein)
    }

    var carbsChange: Double {
        percentChange(current: currentWeek.avgCarbs, previous: previousWeek.avgCarbs)
    }

    var fatChange: Double {
        percentChange(current: currentWeek.avgFat, previous: previousWeek.avgFat)
    }

    private func percentChange(current: Double, previous: Double) -> Double {
        guard previous > 0 else { return 0 }
        return ((current - previous) / previous) * 100
    }
}

enum WeeklyReportCalculator {

    /// Generate a report for a given week offset (0 = current, 1 = last week, etc.)
    static func generateReport(meals: [Meal], weekOffset: Int = 0) -> WeeklyReport {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Find this week's Monday (or the start of the week based on locale)
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else {
            return emptyReport()
        }

        let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: currentWeekStart)!
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!

        let weekMeals = meals.filter { $0.timestamp >= weekStart && $0.timestamp < weekEnd }

        let summaries = (0..<7).compactMap { dayOffset -> NutritionCalculator.DailySummary? in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { return nil }
            let dayMeals = weekMeals.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
            return NutritionCalculator.DailySummary(
                date: date,
                totalCalories: dayMeals.reduce(0) { $0 + $1.totalCalories },
                totalProtein: dayMeals.reduce(0) { $0 + $1.totalProteinGrams },
                totalCarbs: dayMeals.reduce(0) { $0 + $1.totalCarbsGrams },
                totalFat: dayMeals.reduce(0) { $0 + $1.totalFatGrams },
                mealCount: dayMeals.count
            )
        }

        let activeDays = summaries.filter { $0.mealCount > 0 }.count

        return WeeklyReport(
            weekStart: weekStart,
            weekEnd: weekEnd,
            dailySummaries: summaries,
            totalMeals: weekMeals.count,
            activeDays: activeDays
        )
    }

    /// Generate comparison between current and previous week
    static func generateComparison(meals: [Meal]) -> WeekComparison {
        let current = generateReport(meals: meals, weekOffset: 0)
        let previous = generateReport(meals: meals, weekOffset: 1)
        return WeekComparison(currentWeek: current, previousWeek: previous)
    }

    private static func emptyReport() -> WeeklyReport {
        WeeklyReport(
            weekStart: Date(),
            weekEnd: Date(),
            dailySummaries: [],
            totalMeals: 0,
            activeDays: 0
        )
    }
}
