import Foundation
import SwiftData

enum NutritionCalculator {
    struct DailySummary: Identifiable {
        let date: Date
        let totalCalories: Double
        let totalProtein: Double
        let totalCarbs: Double
        let totalFat: Double
        let totalSugar: Double
        let mealCount: Int

        var id: Date { date }
    }

    static func dailySummaries(
        from meals: [Meal],
        days: Int = 7
    ) -> [DailySummary] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Create a lookup of meals grouped by day
        let grouped = Dictionary(grouping: meals) { meal in
            calendar.startOfDay(for: meal.timestamp)
        }

        // Generate entries for each day (including days with no meals)
        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }
            let dayMeals = grouped[date] ?? []
            return DailySummary(
                date: date,
                totalCalories: dayMeals.reduce(0) { $0 + $1.totalCalories },
                totalProtein: dayMeals.reduce(0) { $0 + $1.totalProteinGrams },
                totalCarbs: dayMeals.reduce(0) { $0 + $1.totalCarbsGrams },
                totalFat: dayMeals.reduce(0) { $0 + $1.totalFatGrams },
                totalSugar: dayMeals.reduce(0) { $0 + $1.totalSugarGrams },
                mealCount: dayMeals.count
            )
        }.reversed()
    }

    static func todayTotals(from meals: [Meal]) -> NutrientInfo {
        meals.reduce(NutrientInfo.zero) { total, meal in
            total + NutrientInfo(
                calories: meal.totalCalories,
                proteinGrams: meal.totalProteinGrams,
                carbsGrams: meal.totalCarbsGrams,
                fatGrams: meal.totalFatGrams,
                fiberGrams: meal.totalFiberGrams,
                sugarGrams: meal.totalSugarGrams
            )
        }
    }
}
