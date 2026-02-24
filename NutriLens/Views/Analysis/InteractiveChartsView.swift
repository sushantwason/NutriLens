import SwiftUI
import SwiftData
import Charts

// MARK: - Time Range

enum ChartTimeRange: String, CaseIterable, Identifiable {
    case week = "Week"
    case twoWeeks = "2 Weeks"
    case month = "Month"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .week: return 7
        case .twoWeeks: return 14
        case .month: return 30
        }
    }
}

// MARK: - Nutrient Trend Selection

enum NutrientTrendSelection: String, CaseIterable, Identifiable {
    case protein = "Protein"
    case carbs = "Carbs"
    case fat = "Fat"
    case sugar = "Sugar"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .protein: return .proteinColor
        case .carbs: return .carbsColor
        case .fat: return .fatColor
        case .sugar: return .sugarColor
        }
    }
}

// MARK: - Daily Data Point

private struct DailyDataPoint: Identifiable {
    let date: Date
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let sugar: Double
    let meals: [Meal]

    var id: Date { date }
    var mealCount: Int { meals.count }
}

// MARK: - Macro Stack Entry

private struct MacroStackEntry: Identifiable {
    let date: Date
    let macro: String
    let grams: Double

    var id: String { "\(date.timeIntervalSince1970)-\(macro)" }
}

// MARK: - Chart Tab

private enum ChartTab: String, CaseIterable {
    case daily = "Daily"
    case trends = "Trends"
}

// MARK: - InteractiveChartsView

struct InteractiveChartsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var chartTab: ChartTab = .daily
    @State private var timeRange: ChartTimeRange = .week
    @State private var trendSelection: NutrientTrendSelection = .protein
    @State private var dataPoints: [DailyDataPoint] = []
    @State private var activeGoal: DailyGoal?
    @State private var selectedDay: DailyDataPoint?
    @State private var showDayDetail: Bool = false
    @State private var isLoadingData = false

    // Trends state
    @State private var weeklyBuckets: [WeekBucket] = []
    @State private var monthlyBuckets: [MonthBucket] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("View", selection: $chartTab) {
                    ForEach(ChartTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                switch chartTab {
                case .daily:
                    dailyContent
                case .trends:
                    trendsContent
                }
            }
            .padding()
        }
        .navigationTitle("Detailed Charts")
        .background(Color(.systemGroupedBackground))
        .task {
            await loadData()
            await loadTrendsData()
        }
        .onChange(of: timeRange) { _, _ in
            Task { await loadData() }
        }
        .sheet(isPresented: $showDayDetail) {
            if let day = selectedDay {
                DayDetailSheet(day: day, goal: activeGoal)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Daily Content

    private var dailyContent: some View {
        VStack(spacing: 16) {
            Picker("Time Range", selection: $timeRange) {
                ForEach(ChartTimeRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)

            macroStackedChartCard
            nutrientTrendCard
        }
    }

    // MARK: - Trends Content

    private var trendsContent: some View {
        VStack(spacing: 16) {
            if weeklyBuckets.isEmpty && monthlyBuckets.isEmpty {
                emptyPlaceholder
            } else {
                weeklyCalorieCard
                monthOverMonthCard
                trendsSummaryCard
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        guard !isLoadingData else { return }
        isLoadingData = true
        defer { isLoadingData = false }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let days = timeRange.days

        guard let rangeStart = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            return
        }
        let rangeEnd = today.endOfDay

        var mealDescriptor = FetchDescriptor<Meal>(
            predicate: #Predicate<Meal> {
                $0.isConfirmedByUser == true &&
                $0.timestamp >= rangeStart &&
                $0.timestamp < rangeEnd
            },
            sortBy: [SortDescriptor(\Meal.timestamp, order: .forward)]
        )
        mealDescriptor.fetchLimit = 5000

        let meals: [Meal]
        do {
            meals = try modelContext.fetch(mealDescriptor)
        } catch {
            meals = []
        }

        var goalDescriptor = FetchDescriptor<DailyGoal>(
            predicate: #Predicate<DailyGoal> { $0.isActive == true }
        )
        goalDescriptor.fetchLimit = 1

        let goals: [DailyGoal]
        do {
            goals = try modelContext.fetch(goalDescriptor)
        } catch {
            goals = []
        }

        let grouped = Dictionary(grouping: meals) { meal in
            calendar.startOfDay(for: meal.timestamp)
        }

        var points: [DailyDataPoint] = []
        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: offset, to: rangeStart) else {
                continue
            }
            let dayMeals = grouped[date] ?? []
            points.append(DailyDataPoint(
                date: date,
                calories: dayMeals.reduce(0) { $0 + $1.totalCalories },
                protein: dayMeals.reduce(0) { $0 + $1.totalProteinGrams },
                carbs: dayMeals.reduce(0) { $0 + $1.totalCarbsGrams },
                fat: dayMeals.reduce(0) { $0 + $1.totalFatGrams },
                sugar: dayMeals.reduce(0) { $0 + $1.totalSugarGrams },
                meals: dayMeals
            ))
        }

        self.dataPoints = points
        self.activeGoal = goals.first
    }

    private func loadTrendsData() async {
        let calendar = Calendar.current
        let twelveMonthsAgo = calendar.date(byAdding: .month, value: -12, to: Date()) ?? Date()

        do {
            var descriptor = FetchDescriptor<Meal>(
                predicate: #Predicate<Meal> {
                    $0.isConfirmedByUser == true && $0.timestamp >= twelveMonthsAgo
                },
                sortBy: [SortDescriptor(\Meal.timestamp, order: .forward)]
            )
            descriptor.fetchLimit = 10000
            let meals = try modelContext.fetch(descriptor)

            weeklyBuckets = buildWeeklyBuckets(from: meals)
            monthlyBuckets = buildMonthlyBuckets(from: meals)
        } catch {
            weeklyBuckets = []
            monthlyBuckets = []
        }
    }

    // MARK: - Macro Stacked Bar Chart

    private var macroStackedChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macro Distribution")
                .font(.headline)

            Chart {
                ForEach(macroStackEntries, id: \.id) { entry in
                    BarMark(
                        x: .value("Day", entry.date, unit: .day),
                        y: .value("Grams", entry.grams)
                    )
                    .foregroundStyle(by: .value("Macro", entry.macro))
                    .cornerRadius(2)
                }
            }
            .chartForegroundStyleScale([
                "Protein": Color.proteinColor,
                "Carbs": Color.carbsColor,
                "Fat": Color.fatColor,
                "Sugar": Color.sugarColor
            ])
            .chartLegend(position: .bottom, alignment: .center, spacing: 16)
            .chartXAxis {
                AxisMarks(values: .stride(by: xAxisStride)) { value in
                    AxisValueLabel(format: xAxisLabelFormat)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            handleChartTap(at: location, proxy: proxy, geometry: geometry)
                        }
                }
            }
            .frame(height: 200)

            Text("Tap a bar to see details")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Nutrient Trend Line Chart

    private var nutrientTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nutrient Trend")
                    .font(.headline)
                Spacer()
                Picker("Nutrient", selection: $trendSelection) {
                    ForEach(NutrientTrendSelection.allCases) { nutrient in
                        Text(nutrient.rawValue).tag(nutrient)
                    }
                }
                .pickerStyle(.menu)
            }

            Chart {
                ForEach(dataPoints) { point in
                    let value = trendValue(for: point)

                    LineMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Grams", value)
                    )
                    .foregroundStyle(trendSelection.color)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    AreaMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Grams", value)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [trendSelection.color.opacity(0.3), trendSelection.color.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Grams", value)
                    )
                    .foregroundStyle(trendSelection.color)
                    .symbolSize(timeRange == .week ? 30 : 15)
                }

                if let goal = activeGoal {
                    let target = goalTarget(for: trendSelection, goal: goal)
                    RuleMark(y: .value("Goal", target))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Goal")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: xAxisStride)) { value in
                    AxisValueLabel(format: xAxisLabelFormat)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 200)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Weekly Calorie Trend (from TrendsView)

    private var weeklyCalorieCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Avg Daily Calories by Week")
                .font(.headline)

            if weeklyBuckets.isEmpty {
                emptyPlaceholder
            } else {
                Chart {
                    ForEach(weeklyBuckets) { bucket in
                        BarMark(
                            x: .value("Week", bucket.label),
                            y: .value("Calories", bucket.avgDailyCalories)
                        )
                        .foregroundStyle(.calorieColor.gradient)
                        .cornerRadius(4)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.system(size: 8))
                    }
                }
                .frame(height: 180)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Month-over-Month

    private var monthOverMonthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Month-over-Month")
                .font(.headline)

            let currentAvg = currentMonthAvgCalories
            let previousAvg = previousMonthAvgCalories
            let change = previousAvg > 0 ? ((currentAvg - previousAvg) / previousAvg) * 100 : 0

            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("This Month")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(currentAvg.calorieString)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.calorieColor)
                    Text("avg kcal/day")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text("Last Month")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(previousAvg.calorieString)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("avg kcal/day")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text("Change")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 2) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text(String(format: "%.1f%%", abs(change)))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(change >= 0 ? .nutriOrange : .nutriGreen)
                    Text(change >= 0 ? "increase" : "decrease")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Trends Summary

    private var trendsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)

            let activeBuckets = weeklyBuckets.filter { $0.activeDays > 0 }
            let best = activeBuckets.max(by: { $0.avgDailyCalories < $1.avgDailyCalories })
            let worst = activeBuckets.min(by: { $0.avgDailyCalories < $1.avgDailyCalories })
            let overallAvg = activeBuckets.isEmpty ? 0 :
                activeBuckets.reduce(0.0) { $0 + $1.avgDailyCalories } / Double(activeBuckets.count)
            let totalMeals = weeklyBuckets.reduce(0) { $0 + $1.totalMeals }

            if activeBuckets.isEmpty {
                Text("No meals logged in the last 12 weeks.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                summaryRow(
                    icon: "flame.fill",
                    iconColor: .nutriOrange,
                    title: "Highest Week",
                    detail: best.map { "\($0.label) \u{2014} \($0.avgDailyCalories.calorieString) avg kcal/day" } ?? "N/A"
                )
                summaryRow(
                    icon: "leaf.fill",
                    iconColor: .nutriGreen,
                    title: "Lowest Week",
                    detail: worst.map { "\($0.label) \u{2014} \($0.avgDailyCalories.calorieString) avg kcal/day" } ?? "N/A"
                )
                summaryRow(
                    icon: "chart.bar.fill",
                    iconColor: .nutriBlue,
                    title: "Overall Average",
                    detail: "\(overallAvg.calorieString) kcal/day"
                )
                summaryRow(
                    icon: "fork.knife",
                    iconColor: .nutriPurple,
                    title: "Total Meals",
                    detail: "\(totalMeals) meals over \(activeBuckets.count) active weeks"
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func summaryRow(icon: String, iconColor: Color, title: String, detail: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 24)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(detail)
                    .font(.subheadline.weight(.medium))
            }
            Spacer()
        }
    }

    // MARK: - Helpers

    private var xAxisStride: Calendar.Component {
        switch timeRange {
        case .week: return .day
        case .twoWeeks: return .day
        case .month: return .weekOfYear
        }
    }

    private var xAxisLabelFormat: Date.FormatStyle {
        switch timeRange {
        case .week:
            return .dateTime.weekday(.abbreviated)
        case .twoWeeks:
            return .dateTime.month(.abbreviated).day(.defaultDigits)
        case .month:
            return .dateTime.month(.abbreviated).day(.defaultDigits)
        }
    }

    private var macroStackEntries: [MacroStackEntry] {
        dataPoints.flatMap { point in
            [
                MacroStackEntry(date: point.date, macro: "Protein", grams: point.protein),
                MacroStackEntry(date: point.date, macro: "Carbs", grams: point.carbs),
                MacroStackEntry(date: point.date, macro: "Fat", grams: point.fat),
                MacroStackEntry(date: point.date, macro: "Sugar", grams: point.sugar)
            ]
        }
    }

    private func trendValue(for point: DailyDataPoint) -> Double {
        switch trendSelection {
        case .protein: return point.protein
        case .carbs: return point.carbs
        case .fat: return point.fat
        case .sugar: return point.sugar
        }
    }

    private func goalTarget(for selection: NutrientTrendSelection, goal: DailyGoal) -> Double {
        switch selection {
        case .protein: return goal.proteinGramsTarget
        case .carbs: return goal.carbsGramsTarget
        case .fat: return goal.fatGramsTarget
        case .sugar: return goal.sugarGramsTarget
        }
    }

    private func handleChartTap(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let frame = geometry[plotFrame]
        let xPosition = location.x - frame.origin.x

        guard let tappedDate: Date = proxy.value(atX: xPosition) else { return }

        let calendar = Calendar.current
        let tappedDay = calendar.startOfDay(for: tappedDate)

        if let match = dataPoints.first(where: { calendar.isDate($0.date, inSameDayAs: tappedDay) }) {
            selectedDay = match
            showDayDetail = true
        }
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No data available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }

    // MARK: - Trends Helpers

    private var currentMonthAvgCalories: Double {
        let calendar = Calendar.current
        guard let monthStart = calendar.dateInterval(of: .month, for: Date())?.start else { return 0 }
        let active = weeklyBuckets.filter { $0.weekStart >= monthStart && $0.activeDays > 0 }
        guard !active.isEmpty else { return 0 }
        return active.reduce(0.0) { $0 + $1.avgDailyCalories } / Double(active.count)
    }

    private var previousMonthAvgCalories: Double {
        let calendar = Calendar.current
        guard let currentMonthStart = calendar.dateInterval(of: .month, for: Date())?.start,
              let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart)
        else { return 0 }
        let active = weeklyBuckets.filter { $0.weekStart >= previousMonthStart && $0.weekStart < currentMonthStart && $0.activeDays > 0 }
        guard !active.isEmpty else { return 0 }
        return active.reduce(0.0) { $0 + $1.avgDailyCalories } / Double(active.count)
    }

    private func buildWeeklyBuckets(from meals: [Meal]) -> [WeekBucket] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }

        let weekLabelFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "M/d"
            return f
        }()

        return (0..<12).reversed().compactMap { weekOffset -> WeekBucket? in
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: currentWeekStart),
                  let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)
            else { return nil }

            let weekMeals = meals.filter { $0.timestamp >= weekStart && $0.timestamp < weekEnd }
            let grouped = Dictionary(grouping: weekMeals) { calendar.startOfDay(for: $0.timestamp) }
            let activeDays = grouped.count
            let divisor = max(activeDays, 1)

            return WeekBucket(
                weekStart: weekStart,
                label: weekLabelFormatter.string(from: weekStart),
                avgDailyCalories: weekMeals.reduce(0.0) { $0 + $1.totalCalories } / Double(divisor),
                avgProtein: weekMeals.reduce(0.0) { $0 + $1.totalProteinGrams } / Double(divisor),
                avgCarbs: weekMeals.reduce(0.0) { $0 + $1.totalCarbsGrams } / Double(divisor),
                avgFat: weekMeals.reduce(0.0) { $0 + $1.totalFatGrams } / Double(divisor),
                avgSugar: weekMeals.reduce(0.0) { $0 + $1.totalSugarGrams } / Double(divisor),
                totalMeals: weekMeals.count,
                activeDays: activeDays
            )
        }
    }

    private func buildMonthlyBuckets(from meals: [Meal]) -> [MonthBucket] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let currentMonthStart = calendar.dateInterval(of: .month, for: today)?.start else { return [] }

        let monthLabelFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "MMM yy"
            return f
        }()

        return (0..<12).reversed().compactMap { monthOffset -> MonthBucket? in
            guard let monthStart = calendar.date(byAdding: .month, value: -monthOffset, to: currentMonthStart),
                  let monthInterval = calendar.dateInterval(of: .month, for: monthStart)
            else { return nil }

            let monthMeals = meals.filter { $0.timestamp >= monthStart && $0.timestamp < monthInterval.end }
            let grouped = Dictionary(grouping: monthMeals) { calendar.startOfDay(for: $0.timestamp) }
            let activeDays = grouped.count
            let divisor = max(activeDays, 1)

            return MonthBucket(
                monthStart: monthStart,
                label: monthLabelFormatter.string(from: monthStart),
                avgDailyCalories: monthMeals.reduce(0.0) { $0 + $1.totalCalories } / Double(divisor),
                avgProtein: monthMeals.reduce(0.0) { $0 + $1.totalProteinGrams } / Double(divisor),
                avgCarbs: monthMeals.reduce(0.0) { $0 + $1.totalCarbsGrams } / Double(divisor),
                avgFat: monthMeals.reduce(0.0) { $0 + $1.totalFatGrams } / Double(divisor),
                avgSugar: monthMeals.reduce(0.0) { $0 + $1.totalSugarGrams } / Double(divisor),
                totalMeals: monthMeals.count,
                activeDays: activeDays
            )
        }
    }
}

// MARK: - Trend Bucket Models

struct WeekBucket: Identifiable {
    let id = UUID()
    let weekStart: Date
    let label: String
    let avgDailyCalories: Double
    let avgProtein: Double
    let avgCarbs: Double
    let avgFat: Double
    let avgSugar: Double
    let totalMeals: Int
    let activeDays: Int
}

struct MonthBucket: Identifiable {
    let id = UUID()
    let monthStart: Date
    let label: String
    let avgDailyCalories: Double
    let avgProtein: Double
    let avgCarbs: Double
    let avgFat: Double
    let avgSugar: Double
    let totalMeals: Int
    let activeDays: Int
}

// MARK: - Day Detail Sheet

private struct DayDetailSheet: View {
    let day: DailyDataPoint
    let goal: DailyGoal?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    calorieComparisonSection
                    macroBreakdownSection
                    mealsListSection
                }
                .padding()
            }
            .navigationTitle(day.date.mediumDateString)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    private var calorieComparisonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calorie Summary")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text(day.calories.calorieString)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.calorieColor)
                    Text("Consumed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                if let goal = goal {
                    VStack(spacing: 4) {
                        Text(goal.calorieTarget.calorieString)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text("Goal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        let diff = day.calories - goal.calorieTarget
                        let sign = diff >= 0 ? "+" : ""
                        Text("\(sign)\(diff.calorieString)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(diff >= 0 ? .nutriRed : .nutriGreen)
                        Text(diff >= 0 ? "Over" : "Under")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            if let goal = goal {
                ProgressView(value: day.calories.progressRatio(of: goal.calorieTarget))
                    .tint(day.calories <= goal.calorieTarget ? .calorieColor : .nutriRed)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var macroBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macro Breakdown")
                .font(.headline)

            macroRow(label: "Protein", grams: day.protein, target: goal?.proteinGramsTarget, color: .proteinColor)
            macroRow(label: "Carbs", grams: day.carbs, target: goal?.carbsGramsTarget, color: .carbsColor)
            macroRow(label: "Fat", grams: day.fat, target: goal?.fatGramsTarget, color: .fatColor)
            macroRow(label: "Sugar", grams: day.sugar, target: goal?.sugarGramsTarget, color: .sugarColor)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func macroRow(label: String, grams: Double, target: Double?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(grams.wholeString + "g")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
                if let target = target {
                    Text("/ \(target.wholeString)g")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let target = target {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.opacity(0.15))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: geo.size.width * grams.progressRatio(of: target), height: 8)
                    }
                }
                .frame(height: 8)
            }
        }
    }

    private var mealsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Meals")
                    .font(.headline)
                Spacer()
                Text("\(day.mealCount) meal\(day.mealCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if day.meals.isEmpty {
                Text("No meals logged this day.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(day.meals.sorted(by: { $0.timestamp < $1.timestamp }), id: \.id) { meal in
                    mealRow(meal)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func mealRow(_ meal: Meal) -> some View {
        HStack(spacing: 12) {
            Image(systemName: meal.mealType.icon)
                .font(.title3)
                .foregroundStyle(.nutriOrange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(meal.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(meal.timestamp.shortTimeString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(meal.mealType.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(meal.totalCalories.calorieString) kcal")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.calorieColor)
                HStack(spacing: 4) {
                    Text("P:\(meal.totalProteinGrams.wholeString)")
                        .foregroundStyle(.proteinColor)
                    Text("C:\(meal.totalCarbsGrams.wholeString)")
                        .foregroundStyle(.carbsColor)
                    Text("F:\(meal.totalFatGrams.wholeString)")
                        .foregroundStyle(.fatColor)
                    Text("S:\(meal.totalSugarGrams.wholeString)")
                        .foregroundStyle(.sugarColor)
                }
                .font(.system(size: 9))
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        InteractiveChartsView()
    }
    .modelContainer(for: [Meal.self, DailyGoal.self], inMemory: true)
}
