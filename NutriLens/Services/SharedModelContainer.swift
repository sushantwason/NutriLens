import SwiftData
import Foundation

enum SharedModelContainer {
    static let appGroupID = "group.com.nutrilensapp.shared"

    /// Schema version for tracking — bump when adding non-default properties to any @Model
    /// Current: v2 (added sugarGramsTarget to DailyGoal, sugar/sugarTarget to widget entry)
    /// All new properties MUST have default values to ensure lightweight migration works.
    static let schemaVersion = 2

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
                // Last resort: try with minimal schema to at least launch the app
                print("⚠️ In-memory fallback also failed: \(error). Trying bare-minimum container.")
                let minimal = ModelConfiguration(isStoredInMemoryOnly: true)
                // If this also fails, the app will crash — but at this point the system is
                // fundamentally broken (no memory available). This is unrecoverable.
                return try! ModelContainer(for: schema, configurations: [minimal])
            }
        }
    }()
}
