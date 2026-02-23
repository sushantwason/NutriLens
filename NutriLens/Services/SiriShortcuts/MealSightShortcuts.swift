import AppIntents
import SwiftData
import Foundation

// MARK: - Log Water Intent

struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water in MealSight"
    static var description: IntentDescription = IntentDescription(
        "Log a glass of water to your daily intake in MealSight.",
        categoryName: "Tracking"
    )

    @Parameter(title: "Amount (ml)", default: 250)
    var amountML: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amountML) ml of water")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = SharedModelContainer.sharedModelContainer
        let context = ModelContext(container)

        let entry = WaterEntry(milliliters: Double(amountML))
        context.insert(entry)
        try context.save()

        return .result(
            dialog: "Done! Logged \(amountML) ml of water in MealSight."
        )
    }
}

// MARK: - Today's Summary Intent

struct TodaysSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Today's Meal Summary"
    static var description: IntentDescription = IntentDescription(
        "Get a summary of everything you've eaten today in MealSight.",
        categoryName: "Summary"
    )

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = SharedModelContainer.sharedModelContainer
        let context = ModelContext(container)

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        let predicate = #Predicate<Meal> { meal in
            meal.timestamp >= startOfDay
        }

        let descriptor = FetchDescriptor<Meal>(predicate: predicate)
        let todayMeals = try context.fetch(descriptor)

        guard !todayMeals.isEmpty else {
            return .result(
                dialog: "You haven't logged any meals today in MealSight."
            )
        }

        let totals = NutritionCalculator.todayTotals(from: todayMeals)
        let mealCount = todayMeals.count
        let mealWord = mealCount == 1 ? "meal" : "meals"

        let calories = Int(totals.calories)
        let protein = Int(totals.proteinGrams)
        let carbs = Int(totals.carbsGrams)
        let fat = Int(totals.fatGrams)

        let summary = "Today you've eaten \(calories) calories with \(protein)g protein, \(carbs)g carbs, and \(fat)g fat across \(mealCount) \(mealWord)."

        return .result(dialog: "\(summary)")
    }
}

// MARK: - Calories Remaining Intent

struct CaloriesRemainingIntent: AppIntent {
    static var title: LocalizedStringResource = "Calories Remaining Today"
    static var description: IntentDescription = IntentDescription(
        "Find out how many calories you have left for the day based on your goal in MealSight.",
        categoryName: "Summary"
    )

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = SharedModelContainer.sharedModelContainer
        let context = ModelContext(container)

        // Fetch the active daily goal
        let goalPredicate = #Predicate<DailyGoal> { goal in
            goal.isActive == true
        }
        let goalDescriptor = FetchDescriptor<DailyGoal>(predicate: goalPredicate)
        let goals = try context.fetch(goalDescriptor)
        let calorieTarget = goals.first?.calorieTarget ?? 2000

        // Fetch today's meals
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())

        let mealPredicate = #Predicate<Meal> { meal in
            meal.timestamp >= startOfDay
        }
        let mealDescriptor = FetchDescriptor<Meal>(predicate: mealPredicate)
        let todayMeals = try context.fetch(mealDescriptor)

        let consumed = todayMeals.reduce(0.0) { $0 + $1.totalCalories }
        let remaining = Int(calorieTarget - consumed)
        let target = Int(calorieTarget)
        let eaten = Int(consumed)

        if remaining > 0 {
            return .result(
                dialog: "You have \(remaining) calories remaining today. You've eaten \(eaten) of your \(target) calorie goal."
            )
        } else {
            let over = abs(remaining)
            return .result(
                dialog: "You've exceeded your calorie goal by \(over) calories. You've eaten \(eaten) calories against a \(target) calorie target."
            )
        }
    }
}

// MARK: - App Shortcuts Provider

struct MealSightShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                "Log water in \(.applicationName)",
                "Add water in \(.applicationName)",
                "Track water in \(.applicationName)",
                "Log a glass of water in \(.applicationName)"
            ],
            shortTitle: "Log Water",
            systemImageName: "drop.fill"
        )

        AppShortcut(
            intent: TodaysSummaryIntent(),
            phrases: [
                "What did I eat today in \(.applicationName)",
                "Today's meal summary in \(.applicationName)",
                "Show my food log in \(.applicationName)",
                "How much have I eaten today in \(.applicationName)"
            ],
            shortTitle: "Today's Summary",
            systemImageName: "list.bullet.clipboard"
        )

        AppShortcut(
            intent: CaloriesRemainingIntent(),
            phrases: [
                "How many calories do I have left in \(.applicationName)",
                "Calories remaining in \(.applicationName)",
                "Am I under my calorie goal in \(.applicationName)",
                "How many calories are left today in \(.applicationName)"
            ],
            shortTitle: "Calories Left",
            systemImageName: "flame.fill"
        )
    }
}
