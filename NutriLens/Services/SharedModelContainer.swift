import SwiftData
import Foundation

enum SharedModelContainer {
    static let appGroupID = "group.com.nutrilensapp.shared"

    /// Cached model container — created once and reused.
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Meal.self,
            FoodItem.self,
            NutritionLabel.self,
            DailyGoal.self,
            UserProfile.self,
            WaterEntry.self,
            WeightEntry.self
        ])

        let config: ModelConfiguration
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) {
            let storeURL = containerURL.appendingPathComponent("NutriLens.store")
            config = ModelConfiguration("NutriLens", schema: schema, url: storeURL)
        } else {
            config = ModelConfiguration("NutriLens", schema: schema)
        }

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Fallback to in-memory container so the app/widget doesn't crash
            print("⚠️ Failed to create shared model container: \(error). Using in-memory fallback.")
            let fallback = ModelConfiguration("NutriLensFallback", schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                fatalError("Failed to create even in-memory model container: \(error)")
            }
        }
    }()
}
