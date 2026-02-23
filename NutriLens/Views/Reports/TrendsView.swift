import SwiftUI
import SwiftData
import Charts

struct TrendsView: View {
    @Environment(\.modelContext) private var modelContext

    enum TrendPeriod: String, CaseIterable {
        case monthly = "Monthly"
        case yearly = "Yearly"
    }

    @State private var selectedPeriod: TrendPeriod = .monthly
    @State private var weeklyBuckets: [WeekBucket] = []
    @State private var monthlyBuckets: [MonthBucket] = []
    @State private var isLoading = true

    // MARK: - Data Models

    struct WeekBucket: Identifiable {
        let id = UUID()
        let weekStart: Date
        let label: String
        let avgDailyCalories: Double
        let avgProtein: Double
        let avgCarbs: Double
        let avgFat: Double
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
        let totalMeals: Int
        let activeDays: Int
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                periodPicker

                if isLoading {
                    ProgressView("Loading trends...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    switch selectedPeriod {
                    case .monthly:
                        monthlyContent
                    case .yearly:
                        yearlyContent
                    }

                    summaryStatsCard
                }
            }
            .padding()
        }
        .navigationTitle("Trends")
        .background(Color(.systemGroupedBackground))
        .task {
            await loadAllData()
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(TrendPeriod.allCases, id: \.self) { period in
                Text(period.rawValue).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Monthly Content

    private var monthlyContent: some View {
        VStack(spacing: 16) {
            weeklyCalorieChartCard
            weeklyMacroCard
            monthOverMonthCard
        }
    }

    private var weeklyCalorieChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Avg Daily Calories by Week")
                .font(.headline)

            if weeklyBuckets.isEmpty {
                emptyChartPlaceholder
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
                .frame(height: 200)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var weeklyMacroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Avg Daily Macros by Week")
                .font(.headline)

            if weeklyBuckets.isEmpty {
                emptyChartPlaceholder
            } else {
                let macroData = weeklyBuckets.flatMap { bucket -> [MacroDataPoint] in
                    [
                        MacroDataPoint(week: bucket.label, macro: "Protein", value: bucket.avgProtein),
                        MacroDataPoint(week: bucket.label, macro: "Carbs", value: bucket.avgCarbs),
                        MacroDataPoint(week: bucket.label, macro: "Fat", value: bucket.avgFat),
                    ]
                }

                Chart(macroData) { point in
                    BarMark(
                        x: .value("Week", point.week),
                        y: .value("Grams", point.value)
                    )
                    .foregroundStyle(by: .value("Macro", point.macro))
                    .cornerRadius(3)
                }
                .chartForegroundStyleScale([
                    "Protein": Color.proteinColor,
                    "Carbs": Color.carbsColor,
                    "Fat": Color.fatColor,
                ])
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.system(size: 8))
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
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var monthOverMonthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Month-over-Month")
                .font(.headline)

            let currentMonthAvg = currentMonthAvgCalories
            let previousMonthAvg = previousMonthAvgCalories
            let change = percentChange(current: currentMonthAvg, previous: previousMonthAvg)

            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("This Month")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(currentMonthAvg.calorieString)
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
                    Text(previousMonthAvg.calorieString)
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

    // MARK: - Yearly Content

    private var yearlyContent: some View {
        VStack(spacing: 16) {
            monthlyCalorieChartCard
            yearlyTrendLineCard
        }
    }

    private var monthlyCalorieChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Avg Daily Calories by Month")
                .font(.headline)

            if monthlyBuckets.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart {
                    ForEach(monthlyBuckets) { bucket in
                        BarMark(
                            x: .value("Month", bucket.label),
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
                            .font(.system(size: 9))
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var yearlyTrendLineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calorie Trend")
                .font(.headline)

            if monthlyBuckets.isEmpty {
                emptyChartPlaceholder
            } else {
                Chart {
                    ForEach(monthlyBuckets) { bucket in
                        LineMark(
                            x: .value("Month", bucket.label),
                            y: .value("Calories", bucket.avgDailyCalories)
                        )
                        .foregroundStyle(.nutriBlue)
                        .interpolationMethod(.catmullRom)
                        .symbol(Circle())

                        AreaMark(
                            x: .value("Month", bucket.label),
                            y: .value("Calories", bucket.avgDailyCalories)
                        )
                        .foregroundStyle(.nutriBlue.opacity(0.1))
                        .interpolationMethod(.catmullRom)
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
                            .font(.system(size: 9))
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Summary Stats

    private var summaryStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)

            switch selectedPeriod {
            case .monthly:
                weeklySummaryStats
            case .yearly:
                monthlySummaryStats
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var weeklySummaryStats: some View {
        let activeBuckets = weeklyBuckets.filter { $0.activeDays > 0 }
        let best = activeBuckets.max(by: { $0.avgDailyCalories < $1.avgDailyCalories })
        let worst = activeBuckets.min(by: { $0.avgDailyCalories < $1.avgDailyCalories })
        let overallAvg = activeBuckets.isEmpty ? 0 :
            activeBuckets.reduce(0.0) { $0 + $1.avgDailyCalories } / Double(activeBuckets.count)
        let totalMeals = weeklyBuckets.reduce(0) { $0 + $1.totalMeals }

        return VStack(spacing: 10) {
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
    }

    private var monthlySummaryStats: some View {
        let activeBuckets = monthlyBuckets.filter { $0.activeDays > 0 }
        let best = activeBuckets.max(by: { $0.avgDailyCalories < $1.avgDailyCalories })
        let worst = activeBuckets.min(by: { $0.avgDailyCalories < $1.avgDailyCalories })
        let overallAvg = activeBuckets.isEmpty ? 0 :
            activeBuckets.reduce(0.0) { $0 + $1.avgDailyCalories } / Double(activeBuckets.count)
        let totalMeals = monthlyBuckets.reduce(0) { $0 + $1.totalMeals }

        return VStack(spacing: 10) {
            if activeBuckets.isEmpty {
                Text("No meals logged in the last 12 months.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                summaryRow(
                    icon: "flame.fill",
                    iconColor: .nutriOrange,
                    title: "Highest Month",
                    detail: best.map { "\($0.label) \u{2014} \($0.avgDailyCalories.calorieString) avg kcal/day" } ?? "N/A"
                )

                summaryRow(
                    icon: "leaf.fill",
                    iconColor: .nutriGreen,
                    title: "Lowest Month",
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
                    detail: "\(totalMeals) meals over \(activeBuckets.count) active months"
                )
            }
        }
    }

    // MARK: - Shared Components

    private var emptyChartPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No data available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
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

    // MARK: - Computed Helpers

    private var currentMonthAvgCalories: Double {
        let calendar = Calendar.current
        let now = Date()
        guard let monthStart = calendar.dateInterval(of: .month, for: now)?.start else { return 0 }

        let currentMonthBuckets = weeklyBuckets.filter { $0.weekStart >= monthStart }
        let active = currentMonthBuckets.filter { $0.activeDays > 0 }
        guard !active.isEmpty else { return 0 }
        return active.reduce(0.0) { $0 + $1.avgDailyCalories } / Double(active.count)
    }

    private var previousMonthAvgCalories: Double {
        let calendar = Calendar.current
        let now = Date()
        guard let currentMonthStart = calendar.dateInterval(of: .month, for: now)?.start,
              let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart)
        else { return 0 }

        let prevBuckets = weeklyBuckets.filter {
            $0.weekStart >= previousMonthStart && $0.weekStart < currentMonthStart
        }
        let active = prevBuckets.filter { $0.activeDays > 0 }
        guard !active.isEmpty else { return 0 }
        return active.reduce(0.0) { $0 + $1.avgDailyCalories } / Double(active.count)
    }

    private func percentChange(current: Double, previous: Double) -> Double {
        guard previous > 0 else { return 0 }
        return ((current - previous) / previous) * 100
    }

    // MARK: - Data Loading

    private func loadAllData() async {
        let context = modelContext

        // Only fetch meals from the last 12 months — the maximum range we display.
        // This avoids loading years of historical data into memory.
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
            let meals = try context.fetch(descriptor)

            let weekly = buildWeeklyBuckets(from: meals)
            let monthly = buildMonthlyBuckets(from: meals)

            weeklyBuckets = weekly
            monthlyBuckets = monthly
        } catch {
            weeklyBuckets = []
            monthlyBuckets = []
        }

        isLoading = false
    }

    private func buildWeeklyBuckets(from meals: [Meal]) -> [WeekBucket] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else {
            return []
        }

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

            let grouped = Dictionary(grouping: weekMeals) { meal in
                calendar.startOfDay(for: meal.timestamp)
            }

            let activeDays = grouped.count
            let divisor = max(activeDays, 1)

            let totalCals = weekMeals.reduce(0.0) { $0 + $1.totalCalories }
            let totalProtein = weekMeals.reduce(0.0) { $0 + $1.totalProteinGrams }
            let totalCarbs = weekMeals.reduce(0.0) { $0 + $1.totalCarbsGrams }
            let totalFat = weekMeals.reduce(0.0) { $0 + $1.totalFatGrams }

            let label = weekLabelFormatter.string(from: weekStart)

            return WeekBucket(
                weekStart: weekStart,
                label: label,
                avgDailyCalories: totalCals / Double(divisor),
                avgProtein: totalProtein / Double(divisor),
                avgCarbs: totalCarbs / Double(divisor),
                avgFat: totalFat / Double(divisor),
                totalMeals: weekMeals.count,
                activeDays: activeDays
            )
        }
    }

    private func buildMonthlyBuckets(from meals: [Meal]) -> [MonthBucket] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let currentMonthStart = calendar.dateInterval(of: .month, for: today)?.start else {
            return []
        }

        let monthLabelFormatter: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "MMM yy"
            return f
        }()

        return (0..<12).reversed().compactMap { monthOffset -> MonthBucket? in
            guard let monthStart = calendar.date(byAdding: .month, value: -monthOffset, to: currentMonthStart),
                  let monthInterval = calendar.dateInterval(of: .month, for: monthStart)
            else { return nil }

            let monthEnd = monthInterval.end
            let monthMeals = meals.filter { $0.timestamp >= monthStart && $0.timestamp < monthEnd }

            let grouped = Dictionary(grouping: monthMeals) { meal in
                calendar.startOfDay(for: meal.timestamp)
            }

            let activeDays = grouped.count
            let divisor = max(activeDays, 1)

            let totalCals = monthMeals.reduce(0.0) { $0 + $1.totalCalories }
            let totalProtein = monthMeals.reduce(0.0) { $0 + $1.totalProteinGrams }
            let totalCarbs = monthMeals.reduce(0.0) { $0 + $1.totalCarbsGrams }
            let totalFat = monthMeals.reduce(0.0) { $0 + $1.totalFatGrams }

            let label = monthLabelFormatter.string(from: monthStart)

            return MonthBucket(
                monthStart: monthStart,
                label: label,
                avgDailyCalories: totalCals / Double(divisor),
                avgProtein: totalProtein / Double(divisor),
                avgCarbs: totalCarbs / Double(divisor),
                avgFat: totalFat / Double(divisor),
                totalMeals: monthMeals.count,
                activeDays: activeDays
            )
        }
    }
}

// MARK: - Macro Data Point (for stacked chart)

private struct MacroDataPoint: Identifiable {
    let week: String
    let macro: String
    let value: Double

    /// Stable ID to avoid chart redraws when data hasn't changed
    var id: String { "\(week)-\(macro)" }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TrendsView()
    }
    .modelContainer(for: [Meal.self, DailyGoal.self], inMemory: true)
}
