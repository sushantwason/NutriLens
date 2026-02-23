import SwiftUI

struct MealReminderSettingsView: View {
    @Environment(MealReminderManager.self) private var reminderManager

    @State private var showPermissionDeniedAlert = false

    var body: some View {
        List {
            mainToggleSection
            if reminderManager.isEnabled {
                mealSection(
                    title: "Breakfast",
                    icon: "sunrise.fill",
                    isEnabled: breakfastEnabledBinding,
                    time: breakfastTimeBinding
                )
                mealSection(
                    title: "Lunch",
                    icon: "sun.max.fill",
                    isEnabled: lunchEnabledBinding,
                    time: lunchTimeBinding
                )
                mealSection(
                    title: "Dinner",
                    icon: "moon.fill",
                    isEnabled: dinnerEnabledBinding,
                    time: dinnerTimeBinding
                )
                footerSection
            }
        }
        .navigationTitle("Meal Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Notifications Disabled", isPresented: $showPermissionDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable notifications for MealSight in the Settings app to receive meal reminders.")
        }
    }

    // MARK: - Main Toggle

    private var mainToggleSection: some View {
        Section {
            Toggle(isOn: mainToggleBinding) {
                Label("Enable Reminders", systemImage: "bell.badge.fill")
            }
            .tint(.nutriGreen)
        }
    }

    // MARK: - Meal Section

    private func mealSection(
        title: String,
        icon: String,
        isEnabled: Binding<Bool>,
        time: Binding<Date>
    ) -> some View {
        Section {
            Toggle(isOn: isEnabled) {
                Label(title, systemImage: icon)
            }
            .tint(.nutriGreen)

            if isEnabled.wrappedValue {
                DatePicker(
                    "Time",
                    selection: time,
                    displayedComponents: .hourAndMinute
                )
                .tint(.nutriOrange)
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        Section {
            Text("You'll receive a reminder to log your meal at the scheduled times.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Bindings

    private var mainToggleBinding: Binding<Bool> {
        Binding(
            get: { reminderManager.isEnabled },
            set: { newValue in
                if newValue {
                    Task {
                        let granted = await reminderManager.requestPermission()
                        if granted {
                            reminderManager.isEnabled = true
                            reminderManager.scheduleReminders()
                        } else {
                            reminderManager.isEnabled = false
                            showPermissionDeniedAlert = true
                        }
                    }
                } else {
                    reminderManager.isEnabled = false
                    reminderManager.cancelAllReminders()
                }
            }
        )
    }

    private var breakfastEnabledBinding: Binding<Bool> {
        mealEnabledBinding(
            get: { reminderManager.breakfastEnabled },
            set: { reminderManager.breakfastEnabled = $0 }
        )
    }

    private var lunchEnabledBinding: Binding<Bool> {
        mealEnabledBinding(
            get: { reminderManager.lunchEnabled },
            set: { reminderManager.lunchEnabled = $0 }
        )
    }

    private var dinnerEnabledBinding: Binding<Bool> {
        mealEnabledBinding(
            get: { reminderManager.dinnerEnabled },
            set: { reminderManager.dinnerEnabled = $0 }
        )
    }

    private func mealEnabledBinding(
        get: @escaping () -> Bool,
        set: @escaping (Bool) -> Void
    ) -> Binding<Bool> {
        Binding(
            get: get,
            set: { newValue in
                set(newValue)
                reminderManager.scheduleReminders()
            }
        )
    }

    private var breakfastTimeBinding: Binding<Date> {
        mealTimeBinding(
            get: { reminderManager.breakfastTime },
            set: { reminderManager.breakfastTime = $0 }
        )
    }

    private var lunchTimeBinding: Binding<Date> {
        mealTimeBinding(
            get: { reminderManager.lunchTime },
            set: { reminderManager.lunchTime = $0 }
        )
    }

    private var dinnerTimeBinding: Binding<Date> {
        mealTimeBinding(
            get: { reminderManager.dinnerTime },
            set: { reminderManager.dinnerTime = $0 }
        )
    }

    private func mealTimeBinding(
        get: @escaping () -> Date,
        set: @escaping (Date) -> Void
    ) -> Binding<Date> {
        Binding(
            get: get,
            set: { newValue in
                set(newValue)
                reminderManager.scheduleReminders()
            }
        )
    }
}

#Preview {
    NavigationStack {
        MealReminderSettingsView()
    }
    .environment(MealReminderManager())
}
