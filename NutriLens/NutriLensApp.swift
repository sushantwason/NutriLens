import SwiftUI
import SwiftData
import WidgetKit

@main
struct NutriLensApp: App {
    @State private var subscriptionManager = SubscriptionManager()
    @State private var trialManager = TrialManager()
    @State private var scanCounter = ScanCounter()
    @State private var mealReminderManager = MealReminderManager()
    @Environment(\.scenePhase) private var scenePhase

    let modelContainer: ModelContainer

    init() {
        OwnerBypass.printDeviceUUID()
        AppConstants.seedAppTokenIfNeeded()
        // Reuse the shared container so the app and widget read/write the same store
        modelContainer = SharedModelContainer.sharedModelContainer
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(subscriptionManager)
                .environment(trialManager)
                .environment(scanCounter)
                .environment(mealReminderManager)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
                .task {
                    // Prune photo blobs from meals older than 90 days to limit storage growth
                    let context = ModelContext(modelContainer)
                    Meal.pruneOldPhotos(context: context)
                    // Schedule weekly summary notification with latest stats
                    WeeklySummaryNotifier.scheduleIfNeeded(container: modelContainer)
                }
        }
        .modelContainer(modelContainer)
    }
}
