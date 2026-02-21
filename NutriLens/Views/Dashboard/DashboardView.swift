import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(filter: #Predicate<Meal> { meal in
        meal.isConfirmedByUser == true
    }, sort: \Meal.timestamp, order: .reverse)
    private var allMeals: [Meal]

    @Query(filter: #Predicate<DailyGoal> { $0.isActive == true })
    private var activeGoals: [DailyGoal]

    @Query private var profiles: [UserProfile]

    @State private var coachService = NutritionCoachService()
    @State private var showScanSheet = false

    private var todaysMeals: [Meal] {
        let start = Date().startOfDay
        let end = Date().endOfDay
        return allMeals.filter { $0.timestamp >= start && $0.timestamp < end }
    }

    private var todayTotals: NutrientInfo {
        NutritionCalculator.todayTotals(from: todaysMeals)
    }

    private var goal: DailyGoal? {
        activeGoals.first
    }

    // MARK: - Streak Computed Properties

    private var currentStreak: Int {
        guard let goal else { return 0 }
        return StreakManager.currentStreakLength(meals: Array(allMeals), goal: goal)
    }

    private var longestStreak: Int {
        guard let goal else { return 0 }
        return StreakManager.longestStreak(meals: Array(allMeals), goal: goal)
    }

    // MARK: - Remaining Budget

    private var remainingBudget: MealSuggestionService.RemainingBudget? {
        guard let goal else { return nil }
        return MealSuggestionService.remainingBudget(todayTotals: todayTotals, goal: goal)
    }

    private var mealSuggestion: String? {
        guard let budget = remainingBudget else { return nil }
        return MealSuggestionService.suggestion(for: budget)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    calorieRingSection
                    StreakBadgeView(currentStreak: currentStreak, longestStreak: longestStreak)
                    macroRingsSection
                    WaterProgressCard()
                    WeightSummaryCard()
                    if let budget = remainingBudget {
                        RemainingBudgetCard(budget: budget, suggestion: mealSuggestion)
                    }
                    CoachInsightCard(
                        insight: coachService.latestInsight,
                        isLoading: coachService.isLoading,
                        onRefresh: { fetchCoachInsight() }
                    )
                    weeklyReportLink
                    todayMealsSection
                }
                .padding()
            }
            .navigationTitle("MealSight")
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticService.scanStarted()
                        showScanSheet = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.nutriGreen, in: Circle())
                    }
                }
            }
            .fullScreenCover(isPresented: $showScanSheet) {
                CameraCaptureView()
            }
            .task {
                fetchCoachInsight()
            }
        }
    }

    // MARK: - Coach

    private func fetchCoachInsight() {
        let hash = coachService.progressHash(totals: todayTotals)
        guard coachService.shouldRefresh(currentHash: hash) else { return }
        Task {
            await coachService.fetchInsight(
                todayTotals: todayTotals,
                goal: goal,
                streak: currentStreak,
                restrictions: profiles.first?.dietaryRestrictions ?? []
            )
        }
    }

    // MARK: - Calorie Ring

    private var calorieRingSection: some View {
        VStack(spacing: 8) {
            MacroRingView(
                progress: todayTotals.calories.progressRatio(of: goal?.calorieTarget ?? 2000),
                color: .calorieColor,
                lineWidth: 16,
                size: 140
            ) {
                VStack(spacing: 2) {
                    Text(todayTotals.calories.calorieString)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("/ \((goal?.calorieTarget ?? 2000).calorieString) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Calories Today")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Macro Rings

    private var macroRingsSection: some View {
        HStack(spacing: 16) {
            macroCard(
                title: "Protein",
                value: todayTotals.proteinGrams,
                target: goal?.proteinGramsTarget ?? 150,
                color: .proteinColor
            )
            macroCard(
                title: "Carbs",
                value: todayTotals.carbsGrams,
                target: goal?.carbsGramsTarget ?? 250,
                color: .carbsColor
            )
            macroCard(
                title: "Fat",
                value: todayTotals.fatGrams,
                target: goal?.fatGramsTarget ?? 65,
                color: .fatColor
            )
        }
    }

    private func macroCard(title: String, value: Double, target: Double, color: Color) -> some View {
        VStack(spacing: 8) {
            MacroRingView(
                progress: value.progressRatio(of: target),
                color: color,
                lineWidth: 8,
                size: 60
            ) {
                Text(value.oneDecimalString)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(value.oneDecimalString)/\(target.oneDecimalString)g")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Weekly Report Link

    private var weeklyReportLink: some View {
        NavigationLink {
            WeeklyReportView()
        } label: {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.title3)
                    .foregroundStyle(.nutriGreen)
                    .frame(width: 36, height: 36)
                    .background(.nutriGreen.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly Report")
                        .font(.subheadline.weight(.medium))
                    Text("View your nutrition trends")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Today's Meals

    private var todayMealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's Meals")
                    .font(.headline)
                Spacer()
                Text("\(todaysMeals.count) meals")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if todaysMeals.isEmpty {
                ContentUnavailableView(
                    "No meals yet",
                    systemImage: "fork.knife",
                    description: Text("Tap the camera button to photograph your first meal")
                )
                .frame(height: 150)
            } else {
                ForEach(todaysMeals) { meal in
                    MealRowCard(meal: meal)
                }
            }
        }
    }
}

struct MealRowCard: View {
    let meal: Meal

    var body: some View {
        HStack(spacing: 12) {
            // Meal type icon
            Image(systemName: meal.mealType.icon)
                .font(.title2)
                .foregroundStyle(.nutriGreen)
                .frame(width: 44, height: 44)
                .background(.nutriGreen.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(meal.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Text(meal.timestamp.shortTimeString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(meal.totalCalories.calorieString) kcal")
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 8) {
                    macroLabel("P", meal.totalProteinGrams, .proteinColor)
                    macroLabel("C", meal.totalCarbsGrams, .carbsColor)
                    macroLabel("F", meal.totalFatGrams, .fatColor)
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func macroLabel(_ letter: String, _ value: Double, _ color: Color) -> some View {
        Text("\(letter):\(value.oneDecimalString)")
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(color)
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [Meal.self, DailyGoal.self, WaterEntry.self, WeightEntry.self, UserProfile.self], inMemory: true)
        .environment(SubscriptionManager())
        .environment(TrialManager())
        .environment(HealthKitManager())
        .environment(ScanCounter())
}
