import SwiftUI
import SwiftData
import WidgetKit

struct DashboardView: View {
    @Query(filter: #Predicate<Meal> { meal in
        meal.isConfirmedByUser == true
    }, sort: \Meal.timestamp, order: .reverse)
    private var allMeals: [Meal]

    @Query(filter: #Predicate<DailyGoal> { $0.isActive == true })
    private var activeGoals: [DailyGoal]

    @Query private var profiles: [UserProfile]

    @Environment(\.modelContext) private var modelContext

    @State private var coachService = NutritionCoachService()
    @State private var showScanSheet = false
    @State private var showFoodSearch = false
    @State private var showAIConsent = false
    @AppStorage("mealsight.ai.consent.accepted") private var aiConsentAccepted = false

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

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Branded header with streak + settings
                    brandedHeaderCard

                    // Main calorie + macros hero
                    calorieHeroCard

                    // Scan + Search buttons
                    scanAndSearchButtons

                    // Today's meals
                    todayMealsSection

                    // AI Coach
                    CoachInsightCard(
                        insight: coachService.latestInsight,
                        isLoading: coachService.isLoading,
                        onRefresh: { fetchCoachInsight() }
                    )

                    // Widget upsell (dismissible)
                    WidgetUpsellCard()

                    // Smart Insights link
                    smartInsightsLink

                    // Bottom spacer
                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .refreshable {
                requestScan()
            }
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showScanSheet) {
                CameraCaptureView()
            }
            .sheet(isPresented: $showFoodSearch) {
                TextFoodSearchView()
            }
            .sheet(isPresented: $showAIConsent) {
                AIConsentView(
                    onAccept: {
                        aiConsentAccepted = true
                        showAIConsent = false
                        HapticService.scanStarted()
                        showScanSheet = true
                    },
                    onDecline: {
                        showAIConsent = false
                    }
                )
                .presentationDetents([.large])
                .interactiveDismissDisabled()
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
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color(red: 0.18, green: 0.52, blue: 0.28))
                .frame(width: 44, height: 44)
                .overlay {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                .accessibilityHidden(true)

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

            // Streak counter (compact)
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(cachedCurrentStreak > 0 ? .nutriOrange : .secondary)
                Text("\(cachedCurrentStreak)")
                    .font(.subheadline.weight(.bold))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Current streak")
            .accessibilityValue("\(cachedCurrentStreak) \(cachedCurrentStreak == 1 ? "day" : "days")")

            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Settings")
            .accessibilityHint("Opens app settings")
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Calories today")
            .accessibilityValue("\(todayTotals.calories.calorieString) of \((goal?.calorieTarget ?? 2000).calorieString) kilocalories, \(Int(todayTotals.calories.progressRatio(of: goal?.calorieTarget ?? 2000) * 100)) percent")

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
            .accessibilityHidden(true)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(value.oneDecimalString) of \(target.oneDecimalString) grams, \(Int(min(value / max(target, 1), 1.0) * 100)) percent")
    }

    // MARK: - Scan + Search Buttons

    private var scanAndSearchButtons: some View {
        HStack(spacing: 12) {
            // Scan Meal (primary)
            Button {
                requestScan()
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("Scan Meal")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.24, green: 0.72, blue: 0.40),
                            Color(red: 0.16, green: 0.52, blue: 0.28)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .shadow(color: Color(red: 0.18, green: 0.55, blue: 0.30).opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Scan Meal")
            .accessibilityHint("Opens camera to photograph and analyze a meal")

            // Search Food (secondary)
            Button {
                HapticService.buttonTap()
                showFoodSearch = true
            } label: {
                VStack(spacing: 8) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.nutriGreen)

                    Text("Search")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Search Food")
            .accessibilityHint("Search for food items by name to log manually")
        }
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
                        .accessibilityHidden(true)
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
                .accessibilityElement(children: .combine)
            } else {
                ForEach(todaysMeals) { meal in
                    MealRowCard(meal: meal, onDelete: {
                        deleteMeal(meal)
                    }, onDuplicate: {
                        duplicateMeal(meal)
                    })
                }
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
                streak: cachedCurrentStreak,
                restrictions: profiles.first?.dietaryRestrictions ?? []
            )
        }
    }

    // MARK: - Smart Insights Link

    private var smartInsightsLink: some View {
        NavigationLink {
            SmartInsightsView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile.fill")
                    .font(.body)
                    .foregroundStyle(.nutriPurple)
                    .frame(width: 36, height: 36)
                    .background(.nutriPurple.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Smart Insights")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("View patterns, alerts & suggestions")
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
        .accessibilityElement(children: .combine)
        .accessibilityHint("View patterns, alerts and suggestions")
    }

    private func requestScan() {
        if aiConsentAccepted {
            HapticService.scanStarted()
            showScanSheet = true
        } else {
            showAIConsent = true
        }
    }

    private func deleteMeal(_ meal: Meal) {
        withAnimation {
            HapticService.mealDeleted()
            modelContext.delete(meal)
            try? modelContext.save()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func duplicateMeal(_ meal: Meal) {
        withAnimation {
            let copy = meal.relogCopy()
            modelContext.insert(copy)
            try? modelContext.save()
            HapticService.mealSaved()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

struct MealRowCard: View {
    let meal: Meal
    var onDelete: (() -> Void)?
    var onDuplicate: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @State private var offset: CGFloat = 0
    @State private var startOffset: CGFloat = 0
    private let actionWidth: CGFloat = 70

    var body: some View {
        ZStack {
            leadingAction
            trailingAction
            mainRowContent
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Sub-views (broken up for Swift compiler type-checking)

    private var leadingAction: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { offset = 0 }
                startOffset = 0
                onDuplicate?()
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                    Text("One More")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(width: actionWidth)
                .frame(maxHeight: .infinity)
            }
            .background(.nutriGreen, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityLabel("Log \(meal.name) again")

            Spacer()
        }
    }

    private var trailingAction: some View {
        HStack(spacing: 0) {
            Spacer()

            Button(role: .destructive) {
                onDelete?()
            } label: {
                Image(systemName: "trash.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
            }
            .background(.red, in: RoundedRectangle(cornerRadius: 14))
            .accessibilityLabel("Delete \(meal.name)")
        }
    }

    private var mainRowContent: some View {
        NavigationLink(destination: MealDetailView(meal: meal)) {
            HStack(spacing: 12) {
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
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(meal.name), \(meal.timestamp.shortTimeString)")
        .accessibilityValue("\(meal.totalCalories.calorieString) kilocalories, protein \(meal.totalProteinGrams.oneDecimalString) grams, carbs \(meal.totalCarbsGrams.oneDecimalString) grams, fat \(meal.totalFatGrams.oneDecimalString) grams")
        .accessibilityHint("Opens meal details")
        .accessibilityAddTraits(.isButton)
        .offset(x: offset)
        .highPriorityGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onChanged { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    let proposed = startOffset + value.translation.width
                    offset = min(max(proposed, -actionWidth), actionWidth)
                }
                .onEnded { value in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        if offset < -actionWidth / 2 {
                            offset = -actionWidth
                        } else if offset > actionWidth / 2 {
                            offset = actionWidth
                        } else {
                            offset = 0
                        }
                    }
                    startOffset = offset
                }
        )
        .contextMenu {
            Button {
                onDuplicate?()
            } label: {
                Label("One More", systemImage: "plus.circle")
            }

            Button {
                HapticService.buttonTap()
                meal.isFavorite.toggle()
                try? modelContext.save()
            } label: {
                Label(
                    meal.isFavorite ? "Unfavorite" : "Favorite",
                    systemImage: meal.isFavorite ? "heart.slash" : "heart"
                )
            }

            Divider()

            Button(role: .destructive) {
                onDelete?()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
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
