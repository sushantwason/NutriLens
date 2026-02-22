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
    @State private var scanButtonPressed = false

    // Cached streak values to avoid expensive recalculation on every render
    @State private var cachedCurrentStreak: Int = 0
    @State private var cachedLongestStreak: Int = 0

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
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Branded header
                        brandedHeaderCard

                        // Main calorie + macros hero
                        calorieHeroCard

                        // Streak row
                        streakRow

                        // Water + Weight
                        WaterProgressCard()
                        WeightSummaryCard()

                        // Remaining budget
                        if let budget = remainingBudget {
                            RemainingBudgetCard(budget: budget, suggestion: mealSuggestion)
                        }

                        // AI Coach
                        CoachInsightCard(
                            insight: coachService.latestInsight,
                            isLoading: coachService.isLoading,
                            onRefresh: { fetchCoachInsight() }
                        )

                        // Weekly report
                        weeklyReportLink

                        // Today's meals
                        todayMealsSection

                        // Bottom spacer for FAB clearance
                        Color.clear.frame(height: 90)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .background(Color(.systemGroupedBackground))

                // Floating Scan Button
                scanFAB
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showScanSheet) {
                CameraCaptureView()
            }
            .task {
                recalculateStreaks()
                fetchCoachInsight()
            }
            .onChange(of: allMeals.count) { _, _ in
                recalculateStreaks()
            }
        }
    }

    private func recalculateStreaks() {
        guard let goal else {
            cachedCurrentStreak = 0
            cachedLongestStreak = 0
            return
        }
        let meals = Array(allMeals)
        cachedCurrentStreak = StreakManager.currentStreakLength(meals: meals, goal: goal)
        cachedLongestStreak = StreakManager.longestStreak(meals: meals, goal: goal)
    }

    // MARK: - Branded Header Card

    private var brandedHeaderCard: some View {
        HStack(spacing: 12) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text("MealSight")
                    .font(.title.weight(.bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.25, green: 0.68, blue: 0.38),
                                Color(red: 0.18, green: 0.52, blue: 0.28)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    // MARK: - Calorie Hero Card

    private var calorieHeroCard: some View {
        VStack(spacing: 16) {
            // Main calorie ring
            MacroRingView(
                progress: todayTotals.calories.progressRatio(of: goal?.calorieTarget ?? 2000),
                color: .calorieColor,
                lineWidth: 18,
                size: 160
            ) {
                VStack(spacing: 2) {
                    Text(todayTotals.calories.calorieString)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("of \((goal?.calorieTarget ?? 2000).calorieString)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("kcal")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
            }

            // Macro bar underneath
            HStack(spacing: 0) {
                macroStat(
                    title: "Protein",
                    value: todayTotals.proteinGrams,
                    target: goal?.proteinGramsTarget ?? 150,
                    color: .proteinColor
                )

                capsuleDivider

                macroStat(
                    title: "Carbs",
                    value: todayTotals.carbsGrams,
                    target: goal?.carbsGramsTarget ?? 250,
                    color: .carbsColor
                )

                capsuleDivider

                macroStat(
                    title: "Fat",
                    value: todayTotals.fatGrams,
                    target: goal?.fatGramsTarget ?? 65,
                    color: .fatColor
                )
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        )
    }

    private var capsuleDivider: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(width: 1, height: 32)
    }

    private func macroStat(title: String, value: Double, target: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            // Mini progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.15))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * min(value / max(target, 1), 1.0))
                }
            }
            .frame(height: 4)

            HStack(spacing: 4) {
                Text(value.oneDecimalString)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text("/ \(target.oneDecimalString)g")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    // MARK: - Streak Row

    private var streakRow: some View {
        HStack(spacing: 12) {
            // Current streak
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.nutriOrange.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "flame.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(cachedCurrentStreak > 0 ? .nutriOrange : .secondary)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(cachedCurrentStreak)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("day streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

            // Longest streak
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.nutriPurple.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "trophy.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(cachedLongestStreak > 0 ? .nutriPurple : .secondary)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(cachedLongestStreak)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("best streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Floating Scan Button

    private var scanFAB: some View {
        Button {
            HapticService.scanStarted()
            showScanSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "viewfinder.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                Text("Scan Meal")
                    .font(.callout.weight(.bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.28, green: 0.72, blue: 0.40),
                        Color(red: 0.18, green: 0.55, blue: 0.30)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .shadow(color: Color(red: 0.22, green: 0.62, blue: 0.34).opacity(0.5), radius: 16, y: 8)
        }
        .scaleEffect(scanButtonPressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: scanButtonPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in scanButtonPressed = true }
                .onEnded { _ in scanButtonPressed = false }
        )
        .padding(.bottom, 28)
    }

    // MARK: - Coach

    private func fetchCoachInsight() {
        let hash = coachService.progressHash(totals: todayTotals)
        guard coachService.shouldRefresh(currentHash: hash) else { return }
        Task {
            await coachService.fetchInsight(
                todayTotals: todayTotals,
                goal: goal,
                streak: cachedCurrentStreak,
                restrictions: profiles.first?.dietaryRestrictions ?? []
            )
        }
    }

    // MARK: - Weekly Report Link

    private var weeklyReportLink: some View {
        NavigationLink {
            WeeklyReportView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.body)
                    .foregroundStyle(.nutriGreen)
                    .frame(width: 36, height: 36)
                    .background(.nutriGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Weekly Report")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("View your nutrition trends")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
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
                Text("\(todaysMeals.count) logged")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }

            if todaysMeals.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("No meals logged yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Tap Scan Meal to get started")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
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
                .font(.body.weight(.semibold))
                .foregroundStyle(.nutriGreen)
                .frame(width: 40, height: 40)
                .background(.nutriGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(meal.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                Text(meal.timestamp.shortTimeString)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(meal.totalCalories.calorieString) kcal")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.calorieColor)

                HStack(spacing: 6) {
                    macroLabel("P", meal.totalProteinGrams, .proteinColor)
                    macroLabel("C", meal.totalCarbsGrams, .carbsColor)
                    macroLabel("F", meal.totalFatGrams, .fatColor)
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
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
