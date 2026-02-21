import Foundation

enum MealSuggestionService {
    struct RemainingBudget {
        let calories: Double
        let proteinGrams: Double
        let carbsGrams: Double
        let fatGrams: Double

        var isComplete: Bool {
            calories <= 0 && proteinGrams <= 0 && carbsGrams <= 0 && fatGrams <= 0
        }
    }

    static func remainingBudget(todayTotals: NutrientInfo, goal: DailyGoal) -> RemainingBudget {
        RemainingBudget(
            calories: max(0, goal.calorieTarget - todayTotals.calories),
            proteinGrams: max(0, goal.proteinGramsTarget - todayTotals.proteinGrams),
            carbsGrams: max(0, goal.carbsGramsTarget - todayTotals.carbsGrams),
            fatGrams: max(0, goal.fatGramsTarget - todayTotals.fatGrams)
        )
    }

    static func suggestion(for budget: RemainingBudget) -> String? {
        guard !budget.isComplete else {
            return "You've met all your goals for today!"
        }

        guard budget.calories > 50 else {
            return "You're almost at your calorie target. A light snack would do!"
        }

        // Determine dominant remaining macro by calorie contribution
        let proteinCalories = budget.proteinGrams * 4
        let carbsCalories = budget.carbsGrams * 4
        let fatCalories = budget.fatGrams * 9
        let totalMacroCalories = proteinCalories + carbsCalories + fatCalories

        guard totalMacroCalories > 0 else { return nil }

        let proteinRatio = proteinCalories / totalMacroCalories
        let carbsRatio = carbsCalories / totalMacroCalories

        if proteinRatio > 0.45 {
            return "You need \(budget.proteinGrams.oneDecimalString)g more protein — try chicken, Greek yogurt, or a protein shake."
        } else if carbsRatio > 0.45 {
            return "You need \(budget.carbsGrams.oneDecimalString)g more carbs — try oatmeal, rice, or a banana."
        } else {
            return "You have \(budget.calories.calorieString) kcal left — try a balanced meal like a salad with grilled chicken."
        }
    }
}
