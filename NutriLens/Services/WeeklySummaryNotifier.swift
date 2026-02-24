import Foundation
import UserNotifications
import SwiftData

/// Schedules a weekly summary push notification every Sunday at 7 PM
/// with the user's average calories, protein, and current scan streak.
enum WeeklySummaryNotifier {
    private static let notificationIdentifier = "mealsight.weeklySummary"

    /// Call on app launch / foreground to (re)schedule the weekly notification.
    static func scheduleIfNeeded(container: ModelContainer) {
        let center = UNUserNotificationCenter.current()

        // Check if notification permission is granted
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }

            // Remove any existing weekly summary to reschedule with fresh data
            center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])

            // Compute stats on a background context
            let context = ModelContext(container)
            let body = computeSummaryBody(context: context)

            let content = UNMutableNotificationContent()
            content.title = "Your Weekly Nutrition Summary"
            content.body = body
            content.sound = .default

            // Schedule for Sunday at 19:00
            var dateComponents = DateComponents()
            dateComponents.weekday = 1 // Sunday
            dateComponents.hour = 19
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )

            let request = UNNotificationRequest(
                identifier: notificationIdentifier,
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error {
                    print("WeeklySummaryNotifier: scheduling failed – \(error.localizedDescription)")
                }
            }
        }
    }

    private static func computeSummaryBody(context: ModelContext) -> String {
        let calendar = Calendar.current
        let now = Date()
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
            return "Keep scanning your meals to see weekly stats!"
        }

        var descriptor = FetchDescriptor<Meal>(
            predicate: #Predicate { $0.isConfirmedByUser == true && $0.timestamp >= weekAgo }
        )
        descriptor.sortBy = [SortDescriptor(\.timestamp)]

        let meals: [Meal]
        do {
            meals = try context.fetch(descriptor)
        } catch {
            return "Keep scanning your meals to see weekly stats!"
        }

        guard !meals.isEmpty else {
            return "No meals logged this week. Start scanning to build your streak!"
        }

        let totalCal = meals.reduce(0.0) { $0 + $1.totalCalories }
        let totalProtein = meals.reduce(0.0) { $0 + $1.totalProteinGrams }
        let daysWithMeals = Set(meals.map { calendar.startOfDay(for: $0.timestamp) }).count
        let avgCal = Int(totalCal / Double(max(daysWithMeals, 1)))
        let avgProtein = Int(totalProtein / Double(max(daysWithMeals, 1)))
        let scanStreak = StreakManager.currentScanStreak(meals: meals)

        var parts: [String] = []
        parts.append("\(avgCal) kcal avg")
        parts.append("\(avgProtein)g protein/day")
        if scanStreak > 0 {
            parts.append("\(scanStreak)-day streak")
        }

        return "This week: " + parts.joined(separator: ", ") + ". Keep it up!"
    }
}
