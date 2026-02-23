import SwiftUI
import SwiftData

struct AchievementsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var totalMeals: Int = 0
    @State private var uniqueDays: Int = 0
    @State private var currentStreak: Int = 0
    @State private var isLoading = true

    var body: some View {
        List {
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 20)
                }
            } else {
                Section("Milestones") {
                    milestoneRow(
                        icon: "fork.knife.circle.fill",
                        title: "First Meal",
                        description: "Log your first meal",
                        achieved: totalMeals >= 1,
                        color: .nutriGreen
                    )
                    milestoneRow(
                        icon: "10.circle.fill",
                        title: "Getting Started",
                        description: "Log 10 meals",
                        achieved: totalMeals >= 10,
                        progress: "\(min(totalMeals, 10))/10",
                        color: .nutriBlue
                    )
                    milestoneRow(
                        icon: "50.circle.fill",
                        title: "Dedicated Logger",
                        description: "Log 50 meals",
                        achieved: totalMeals >= 50,
                        progress: "\(min(totalMeals, 50))/50",
                        color: .nutriPurple
                    )
                    milestoneRow(
                        icon: "star.circle.fill",
                        title: "Century Club",
                        description: "Log 100 meals",
                        achieved: totalMeals >= 100,
                        progress: "\(min(totalMeals, 100))/100",
                        color: .nutriOrange
                    )
                }

                Section("Badges") {
                    badgeRow(
                        icon: "flame.fill",
                        title: "On Fire",
                        description: "Reach a 3-day streak",
                        achieved: currentStreak >= 3,
                        color: .nutriOrange
                    )
                    badgeRow(
                        icon: "flame.circle.fill",
                        title: "Streak Master",
                        description: "Reach a 7-day streak",
                        achieved: currentStreak >= 7,
                        color: .nutriRed
                    )
                    badgeRow(
                        icon: "calendar.circle.fill",
                        title: "Week Warrior",
                        description: "Log meals on 7 different days",
                        achieved: uniqueDays >= 7,
                        color: .nutriGreen
                    )
                    badgeRow(
                        icon: "calendar.badge.checkmark",
                        title: "Monthly Champion",
                        description: "Log meals on 30 different days",
                        achieved: uniqueDays >= 30,
                        color: .nutriBlue
                    )
                }
            }
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        // Run heavy computation off main actor
        let context = modelContext
        let meals: [Meal]
        let goals: [DailyGoal]
        do {
            let mealDescriptor = FetchDescriptor<Meal>(
                predicate: #Predicate<Meal> { $0.isConfirmedByUser == true }
            )
            meals = try context.fetch(mealDescriptor)

            let goalDescriptor = FetchDescriptor<DailyGoal>(
                predicate: #Predicate<DailyGoal> { $0.isActive == true }
            )
            goals = try context.fetch(goalDescriptor)
        } catch {
            isLoading = false
            return
        }

        let count = meals.count
        let days = Set(meals.map { Calendar.current.startOfDay(for: $0.timestamp) }).count
        let streak: Int
        if let goal = goals.first {
            streak = StreakManager.currentStreakLength(meals: meals, goal: goal)
        } else {
            streak = 0
        }

        await MainActor.run {
            totalMeals = count
            uniqueDays = days
            currentStreak = streak
            isLoading = false
        }
    }

    private func milestoneRow(icon: String, title: String, description: String, achieved: Bool, progress: String? = nil, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(achieved ? color : .gray.opacity(0.4))
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if achieved {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.nutriGreen)
            } else if let progress {
                Text(progress)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func badgeRow(icon: String, title: String, description: String, achieved: Bool, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(achieved ? color : .gray.opacity(0.4))
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if achieved {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.nutriGreen)
            } else {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        AchievementsView()
            .modelContainer(for: [Meal.self, DailyGoal.self], inMemory: true)
    }
}
