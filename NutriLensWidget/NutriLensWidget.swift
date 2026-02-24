import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Entry

struct NutritionEntry: TimelineEntry {
    let date: Date
    let calories: Double
    let calorieTarget: Double
    let protein: Double
    let proteinTarget: Double
    let carbs: Double
    let carbsTarget: Double
    let fat: Double
    let fatTarget: Double
    let sugar: Double
    let sugarTarget: Double
    let mealCount: Int
    let waterML: Double
    let waterTarget: Double

    static let placeholder = NutritionEntry(
        date: .now,
        calories: 1450,
        calorieTarget: 2000,
        protein: 85,
        proteinTarget: 150,
        carbs: 180,
        carbsTarget: 250,
        fat: 45,
        fatTarget: 65,
        sugar: 30,
        sugarTarget: 50,
        mealCount: 3,
        waterML: 1500,
        waterTarget: 2000
    )
}

// MARK: - Timeline Provider

struct NutriLensTimelineProvider: TimelineProvider {
    let modelContainer = SharedModelContainer.sharedModelContainer

    func placeholder(in context: Context) -> NutritionEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (NutritionEntry) -> Void) {
        let entry = fetchEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NutritionEntry>) -> Void) {
        let entry = fetchEntry()
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func fetchEntry() -> NutritionEntry {
        let context = ModelContext(modelContainer)

        let start = Date().startOfDay
        let end = Date().endOfDay

        // Fetch today's meals
        let mealDescriptor = FetchDescriptor<Meal>(
            predicate: #Predicate<Meal> {
                $0.isConfirmedByUser == true && $0.timestamp >= start && $0.timestamp < end
            }
        )
        let meals = (try? context.fetch(mealDescriptor)) ?? []

        // Fetch active goal
        let goalDescriptor = FetchDescriptor<DailyGoal>(
            predicate: #Predicate<DailyGoal> { $0.isActive == true }
        )
        let goal = (try? context.fetch(goalDescriptor))?.first

        // Fetch today's water
        let waterDescriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate<WaterEntry> {
                $0.timestamp >= start && $0.timestamp < end
            }
        )
        let waterEntries = (try? context.fetch(waterDescriptor)) ?? []
        let waterML = waterEntries.reduce(0) { $0 + $1.milliliters }

        // Sum nutrients
        let totalCalories = meals.reduce(0) { $0 + $1.totalCalories }
        let totalProtein = meals.reduce(0) { $0 + $1.totalProteinGrams }
        let totalCarbs = meals.reduce(0) { $0 + $1.totalCarbsGrams }
        let totalFat = meals.reduce(0) { $0 + $1.totalFatGrams }
        let totalSugar = meals.reduce(0) { $0 + $1.totalSugarGrams }

        return NutritionEntry(
            date: Date(),
            calories: totalCalories,
            calorieTarget: goal?.calorieTarget ?? 2000,
            protein: totalProtein,
            proteinTarget: goal?.proteinGramsTarget ?? 150,
            carbs: totalCarbs,
            carbsTarget: goal?.carbsGramsTarget ?? 250,
            fat: totalFat,
            fatTarget: goal?.fatGramsTarget ?? 65,
            sugar: totalSugar,
            sugarTarget: goal?.sugarGramsTarget ?? 50,
            mealCount: meals.count,
            waterML: waterML,
            waterTarget: goal?.waterTargetML ?? 2000
        )
    }
}

// MARK: - Home Screen Widget

struct NutriLensWidget: Widget {
    let kind: String = "NutriLensWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutriLensTimelineProvider()) { entry in
            NutriLensWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("MealSight")
        .description("Track your daily nutrition at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Lock Screen Widget

struct NutriLensLockScreenWidget: Widget {
    let kind: String = "NutriLensLockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutriLensTimelineProvider()) { entry in
            NutriLensLockScreenEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("MealSight")
        .description("Quick nutrition summary.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Widget Entry View Router

struct NutriLensWidgetEntryView: View {
    let entry: NutritionEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct NutriLensLockScreenEntryView: View {
    let entry: NutritionEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            LockScreenCircularView(entry: entry)
        case .accessoryRectangular:
            LockScreenRectangularView(entry: entry)
        default:
            LockScreenCircularView(entry: entry)
        }
    }
}