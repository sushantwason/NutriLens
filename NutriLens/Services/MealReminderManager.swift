import Foundation
import UserNotifications
import SwiftUI

@MainActor @Observable
final class MealReminderManager {

    // MARK: - Constants

    private enum Constants {
        static let categoryIdentifier = "mealsight.mealReminder"
        static let logMealActionIdentifier = "mealsight.action.logMeal"

        static func reminderIdentifier(for mealType: MealType) -> String {
            "mealsight.reminder.\(mealType.rawValue)"
        }

        /// Default times as seconds since midnight
        static let defaultBreakfastTime: TimeInterval = 8 * 3600           // 08:00
        static let defaultLunchTime: TimeInterval = 12.5 * 3600            // 12:30
        static let defaultDinnerTime: TimeInterval = 18.5 * 3600           // 18:30
    }

    // MARK: - Stored Properties

    @ObservationIgnored
    @AppStorage("mealReminders.isEnabled")
    var isEnabled: Bool = false

    @ObservationIgnored
    @AppStorage("mealReminders.breakfastEnabled")
    var breakfastEnabled: Bool = true

    @ObservationIgnored
    @AppStorage("mealReminders.lunchEnabled")
    var lunchEnabled: Bool = true

    @ObservationIgnored
    @AppStorage("mealReminders.dinnerEnabled")
    var dinnerEnabled: Bool = true

    @ObservationIgnored
    @AppStorage("mealReminders.breakfastTimeInterval")
    private var breakfastTimeInterval: TimeInterval = Constants.defaultBreakfastTime

    @ObservationIgnored
    @AppStorage("mealReminders.lunchTimeInterval")
    private var lunchTimeInterval: TimeInterval = Constants.defaultLunchTime

    @ObservationIgnored
    @AppStorage("mealReminders.dinnerTimeInterval")
    private var dinnerTimeInterval: TimeInterval = Constants.defaultDinnerTime

    /// Date-based accessors for DatePicker binding
    var breakfastTime: Date {
        get { Self.dateFromTimeInterval(breakfastTimeInterval) }
        set { breakfastTimeInterval = Self.timeIntervalFromDate(newValue) }
    }

    var lunchTime: Date {
        get { Self.dateFromTimeInterval(lunchTimeInterval) }
        set { lunchTimeInterval = Self.timeIntervalFromDate(newValue) }
    }

    var dinnerTime: Date {
        get { Self.dateFromTimeInterval(dinnerTimeInterval) }
        set { dinnerTimeInterval = Self.timeIntervalFromDate(newValue) }
    }

    private static func dateFromTimeInterval(_ interval: TimeInterval) -> Date {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hours
        components.minute = minutes
        return Calendar.current.date(from: components) ?? Date()
    }

    private static func timeIntervalFromDate(_ date: Date) -> TimeInterval {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return TimeInterval((components.hour ?? 0) * 3600 + (components.minute ?? 0) * 60)
    }

    // MARK: - Private

    private let notificationCenter = UNUserNotificationCenter.current()

    // MARK: - Initialization

    init() {
        registerNotificationCategory()
    }

    // MARK: - Permission

    /// Requests notification permission from the user. Returns `true` if granted.
    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .sound]
            )
            return granted
        } catch {
            print("MealReminderManager: permission request failed – \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Schedule All

    /// Cancels any existing meal reminders and reschedules notifications for
    /// breakfast, lunch, and dinner at the currently configured times.
    func scheduleReminders() {
        cancelAllReminders()
        guard isEnabled else { return }

        if breakfastEnabled {
            scheduleSingleReminder(for: .breakfast, secondsSinceMidnight: breakfastTimeInterval)
        }
        if lunchEnabled {
            scheduleSingleReminder(for: .lunch, secondsSinceMidnight: lunchTimeInterval)
        }
        if dinnerEnabled {
            scheduleSingleReminder(for: .dinner, secondsSinceMidnight: dinnerTimeInterval)
        }
    }

    // MARK: - Cancel All

    /// Removes all pending meal reminder notifications.
    func cancelAllReminders() {
        let identifiers = [MealType.breakfast, .lunch, .dinner]
            .map { Constants.reminderIdentifier(for: $0) }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Update Individual Reminder

    /// Cancels and reschedules the notification for a specific meal type.
    func updateReminder(for mealType: MealType) {
        let identifier = Constants.reminderIdentifier(for: mealType)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard isEnabled else { return }

        let time: TimeInterval
        let enabled: Bool
        switch mealType {
        case .breakfast: time = breakfastTimeInterval; enabled = breakfastEnabled
        case .lunch:     time = lunchTimeInterval; enabled = lunchEnabled
        case .dinner:    time = dinnerTimeInterval; enabled = dinnerEnabled
        case .snack:     return // snack reminders are not supported
        }

        guard enabled else { return }
        scheduleSingleReminder(for: mealType, secondsSinceMidnight: time)
    }

    // MARK: - Private Helpers

    private func registerNotificationCategory() {
        let logMealAction = UNNotificationAction(
            identifier: Constants.logMealActionIdentifier,
            title: "Log Meal",
            options: .foreground
        )

        let category = UNNotificationCategory(
            identifier: Constants.categoryIdentifier,
            actions: [logMealAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([category])
    }

    private func scheduleSingleReminder(
        for mealType: MealType,
        secondsSinceMidnight: TimeInterval
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Time for \(mealType.displayName)!"
        content.body = bodyMessage(for: mealType)
        content.sound = .default
        content.categoryIdentifier = Constants.categoryIdentifier

        var dateComponents = DateComponents()
        let totalSeconds = Int(secondsSinceMidnight)
        dateComponents.hour = totalSeconds / 3600
        dateComponents.minute = (totalSeconds % 3600) / 60

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )

        let request = UNNotificationRequest(
            identifier: Constants.reminderIdentifier(for: mealType),
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error {
                print("MealReminderManager: failed to schedule \(mealType.rawValue) – \(error.localizedDescription)")
            }
        }
    }

    private func bodyMessage(for mealType: MealType) -> String {
        switch mealType {
        case .breakfast:
            return "Start your day right! Log your breakfast to stay on track \u{1F37D}\u{FE0F}"
        case .lunch:
            return "Don't forget to log your meal to stay on track \u{1F37D}\u{FE0F}"
        case .dinner:
            return "Wrap up your day! Log your dinner to keep your streak going \u{1F37D}\u{FE0F}"
        case .snack:
            return "Don't forget to log your snack \u{1F37D}\u{FE0F}"
        }
    }
}
