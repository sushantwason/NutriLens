import SwiftUI
import SwiftData
import WidgetKit

@main
struct NutriLensApp: App {
    @State private var subscriptionManager = SubscriptionManager()
    @State private var trialManager = TrialManager()
    @State private var healthKitManager = HealthKitManager()
    @State private var scanCounter = ScanCounter()
    @State private var mealReminderManager = MealReminderManager()

    let modelContainer: ModelContainer

    init() {
        OwnerBypass.printDeviceUUID()

        // Use shared App Group container so widgets can read the same data
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
            forSecurityApplicationGroupIdentifier: SharedModelContainer.appGroupID
        ) {
            let storeURL = containerURL.appendingPathComponent("NutriLens.store")
            config = ModelConfiguration("NutriLens", schema: schema, url: storeURL)
        } else {
            config = ModelConfiguration("NutriLens", schema: schema)
        }

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(subscriptionManager)
                .environment(trialManager)
                .environment(healthKitManager)
                .environment(scanCounter)
                .environment(mealReminderManager)
        }
        .modelContainer(modelContainer)
    }
}
