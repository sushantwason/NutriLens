import SwiftUI
import SwiftData

struct AchievementsView: View {
    @Query(filter: #Predicate<Meal> { $0.isConfirmedByUser == true },
           sort: \Meal.timestamp, order: .reverse)
    private var allMeals: [Meal]
    @Query(filter: #Predicate<DailyGoal> { $0.isActive == true }) private var activeGoals: [DailyGoal]

    private var goal: DailyGoal? { activeGoals.first }

    // Cache expensive computations with @State
    @State private var cachedTotalMeals: Int = 0
    @State private var cachedUniqueDays: Int = 0
    @State private var cachedCurrentStreak: Int = 0

    var body: some View {
        List {
            Section("Milestones") {
                milestoneRow(
                    icon: "fork.knife.circle.fill",
                    title: "First Meal",
                    description: "Log your first meal",
                    achieved: cachedTotalMeals >= 1,
                    color: .nutriGreen
                )
                milestoneRow(
                    icon: "10.circle.fill",
                    title: "Getting Started",
                    description: "Log 10 meals",
                    achieved: cachedTotalMeals >= 10,
                    progress: "\(min(cachedTotalMeals, 10))/10",
                    color: .nutriBlue
                )
                milestoneRow(
                    icon: "50.circle.fill",
                    title: "Dedicated Logger",
                    description: "Log 50 meals",
                    achieved: cachedTotalMeals >= 50,
                    progress: "\(min(cachedTotalMeals, 50))/50",
                    color: .nutriPurple
                )
                milestoneRow(
                    icon: "star.circle.fill",
                    title: "Century Club",
                    description: "Log 100 meals",
                    achieved: cachedTotalMeals >= 100,
                    progress: "\(min(cachedTotalMeals, 100))/100",
                    color: .nutriOrange
                )
            }

            Section("Badges") {
                badgeRow(
                    icon: "flame.fill",
                    title: "On Fire",
                    description: "Reach a 3-day streak",
                    achieved: cachedCurrentStreak >= 3,
                    color: .nutriOrange
                )
                badgeRow(
                    icon: "flame.circle.fill",
                    title: "Streak Master",
                    description: "Reach a 7-day streak",
                    achieved: cachedCurrentStreak >= 7,
                    color: .nutriRed
                )
                badgeRow(
                    icon: "calendar.circle.fill",
                    title: "Week Warrior",
                    description: "Log meals on 7 different days",
                    achieved: cachedUniqueDays >= 7,
                    color: .nutriGreen
                )
                badgeRow(
                    icon: "calendar.badge.checkmark",
                    title: "Monthly Champion",
                    description: "Log meals on 30 different days",
                    achieved: cachedUniqueDays >= 30,
                    color: .nutriBlue
                )
            }
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            recalculate()
        }
    }

    private func recalculate() {
        cachedTotalMeals = allMeals.count
        cachedUniqueDays = Set(allMeals.map { Calendar.current.startOfDay(for: $0.timestamp) }).count
        if let goal {
            cachedCurrentStreak = StreakManager.currentStreakLength(meals: Array(allMeals), goal: goal)
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
