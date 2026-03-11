import SwiftUI
import SwiftData

struct AchievementsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var totalMeals: Int = 0
    @State private var uniqueDays: Int = 0
    @State private var currentStreak: Int = 0
    @State private var longestStreak: Int = 0
    @State private var isLoading = true

    private var allMilestones: [MilestoneItem] {
        [
            MilestoneItem(icon: "fork.knife.circle.fill", title: "First Bite", subtitle: "Log your first meal", threshold: 1, current: totalMeals, color: .nutriGreen, reward: "You're on your way!"),
            MilestoneItem(icon: "10.circle.fill", title: "Getting Started", subtitle: "Log 10 meals", threshold: 10, current: totalMeals, color: .nutriBlue, reward: "Building the habit!"),
            MilestoneItem(icon: "50.circle.fill", title: "Dedicated Tracker", subtitle: "Log 50 meals", threshold: 50, current: totalMeals, color: .nutriPurple, reward: "Truly committed!"),
            MilestoneItem(icon: "star.circle.fill", title: "Century Club", subtitle: "Log 100 meals", threshold: 100, current: totalMeals, color: .nutriOrange, reward: "Nutrition master!"),
            MilestoneItem(icon: "crown.fill", title: "Elite Logger", subtitle: "Log 500 meals", threshold: 500, current: totalMeals, color: .calorieColor, reward: "Legendary status!"),
        ]
    }

    private var allBadges: [BadgeItem] {
        [
            BadgeItem(icon: "flame.fill", title: "On Fire", subtitle: "3-day logging streak", achieved: currentStreak >= 3, color: .nutriOrange),
            BadgeItem(icon: "flame.circle.fill", title: "Streak Master", subtitle: "7-day logging streak", achieved: currentStreak >= 7, color: .nutriRed),
            BadgeItem(icon: "bolt.fill", title: "Unstoppable", subtitle: "14-day logging streak", achieved: currentStreak >= 14, color: .calorieColor),
            BadgeItem(icon: "calendar.circle.fill", title: "Week Warrior", subtitle: "Log on 7 different days", achieved: uniqueDays >= 7, color: .nutriGreen),
            BadgeItem(icon: "calendar.badge.checkmark", title: "Monthly Champion", subtitle: "Log on 30 different days", achieved: uniqueDays >= 30, color: .nutriBlue),
            BadgeItem(icon: "trophy.fill", title: "Longest Streak", subtitle: "Reach a 30-day best streak", achieved: longestStreak >= 30, color: .nutriPurple),
        ]
    }

    var body: some View {
        ScrollView {
            if isLoading {
                VStack {
                    Spacer(minLength: 100)
                    ProgressView()
                    Spacer(minLength: 100)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 20) {
                    // Stats summary
                    statsHeader

                    // Milestones
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Milestones")
                            .font(.headline)
                            .padding(.horizontal, 4)

                        ForEach(allMilestones) { milestone in
                            milestoneCard(milestone)
                        }
                    }

                    // Badges
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Badges")
                            .font(.headline)
                            .padding(.horizontal, 4)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(allBadges) { badge in
                                badgeCard(badge)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            AnalyticsService.track(.achievementsViewed)
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack(spacing: 0) {
            statBubble(value: "\(totalMeals)", label: "Meals", color: .nutriGreen)
            statBubble(value: "\(uniqueDays)", label: "Days", color: .nutriBlue)
            statBubble(value: "\(currentStreak)", label: "Streak", color: .nutriOrange)
            statBubble(value: "\(longestStreak)", label: "Best", color: .nutriPurple)
        }
        .padding(.vertical, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func statBubble(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Milestone Card

    private func milestoneCard(_ item: MilestoneItem) -> some View {
        HStack(spacing: 14) {
            // Icon with achievement glow
            ZStack {
                if item.achieved {
                    Circle()
                        .fill(item.color.opacity(0.15))
                        .frame(width: 52, height: 52)
                }
                Image(systemName: item.icon)
                    .font(.title2)
                    .foregroundStyle(item.achieved ? item.color : .gray.opacity(0.35))
                    .frame(width: 44, height: 44)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                    if item.achieved {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(item.color)
                    }
                }
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if item.achieved {
                    Text(item.reward)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(item.color)
                } else {
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(item.color.opacity(0.12))
                            Capsule()
                                .fill(item.color)
                                .frame(width: geo.size.width * item.progress)
                        }
                    }
                    .frame(height: 6)
                    .clipShape(Capsule())
                }
            }

            Spacer()

            if !item.achieved {
                Text("\(item.current)/\(item.threshold)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Badge Card

    private func badgeCard(_ item: BadgeItem) -> some View {
        VStack(spacing: 10) {
            ZStack {
                if item.achieved {
                    Circle()
                        .fill(item.color.opacity(0.12))
                        .frame(width: 56, height: 56)
                }
                Image(systemName: item.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(item.achieved ? item.color : .gray.opacity(0.3))
            }

            VStack(spacing: 2) {
                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(item.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !item.achieved {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Data Loading

    private func loadData() async {
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
        let best: Int
        if let goal = goals.first {
            streak = StreakManager.currentStreakLength(meals: meals, goal: goal)
            best = StreakManager.longestStreak(meals: meals, goal: goal)
        } else {
            streak = 0
            best = 0
        }

        await MainActor.run {
            totalMeals = count
            uniqueDays = days
            currentStreak = streak
            longestStreak = best
            isLoading = false
        }
    }
}

// MARK: - Models

private struct MilestoneItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let threshold: Int
    let current: Int
    let color: Color
    let reward: String

    var achieved: Bool { current >= threshold }
    var progress: CGFloat { CGFloat(min(current, threshold)) / CGFloat(max(threshold, 1)) }
}

private struct BadgeItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let achieved: Bool
    let color: Color
}

#Preview {
    NavigationStack {
        AchievementsView()
            .modelContainer(for: [Meal.self, DailyGoal.self], inMemory: true)
    }
}
