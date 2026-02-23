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

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .protein: return .proteinColor
        case .carbs: return .carbsColor
        case .fat: return .fatColor
        }
    }
}

// MARK: - Daily Data Point

/// A single day's aggregated nutrition data for charting.
private struct DailyDataPoint: Identifiable {
    let date: Date
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let meals: [Meal]

    var id: Date { date }

    var mealCount: Int { meals.count }
}

// MARK: - Macro Stack Entry

/// One segment of a stacked bar chart representing a single macro for a day.
private struct MacroStackEntry: Identifiable {
    let date: Date
    let macro: String
    let grams: Double
    let color: Color

    var id: String { "\(date.timeIntervalSince1970)-\(macro)" }
}

// MARK: - InteractiveChartsView

struct InteractiveChartsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var timeRange: ChartTimeRange = .week
    @State private var trendSelection: NutrientTrendSelection = .protein
    @State private var dataPoints: [DailyDataPoint] = []
    @State private var activeGoal: DailyGoal?
    @State private var selectedDay: DailyDataPoint?
    @State private var showDayDetail: Bool = false
    @State private var isLoadingData = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                timeRangePicker
                calorieChartCard
                macroStackedChartCard
                nutrientTrendCard
            }
            .padding()
        }
        .navigationTitle("Nutrition Charts")
        .background(Color(.systemGroupedBackground))
        .task {
            await loadData()
        }
        .onChange(of: timeRange) { _, _ in
            Task { await loadData() }
        }
        .sheet(isPresented: $showDayDetail) {
            if let day = selectedDay {
                DayDetailSheet(
                    day: day,
                    goal: activeGoal
                )
                .presentationDetents([.medium, .large])
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

        // Fetch confirmed meals in range using FetchDescriptor to avoid @Query re-render issues
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

        // Fetch active goal
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

        // Group meals by day
        let grouped = Dictionary(grouping: meals) { meal in
            calendar.startOfDay(for: meal.timestamp)
        }

        // Build data points for every day in range (including empty days)
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
                meals: dayMeals
            ))
        }

        // Already on MainActor via View context — assign directly
        self.dataPoints = points
        self.activeGoal = goals.first
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        Picker("Time Range", selection: $timeRange) {
            ForEach(ChartTimeRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Calorie Bar Chart

    private var calorieChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily Calories")
                    .font(.headline)
                Spacer()
                if !dataPoints.isEmpty {
                    let avg = dataPoints.map(\.calories).reduce(0, +) / Double(max(dataPoints.count, 1))
                    Text("Avg: \(avg.calorieString) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Chart {
                ForEach(dataPoints) { point in
                    BarMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Calories", point.calories)
                    )
                    .foregroundStyle(.calorieColor.gradient)
                    .cornerRadius(4)
                }

                if let goal = activeGoal {
                    RuleMark(y: .value("Goal", goal.calorieTarget))
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
                "Fat": Color.fatColor
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
            .frame(height: 200)
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
                MacroStackEntry(date: point.date, macro: "Protein", grams: point.protein, color: .proteinColor),
                MacroStackEntry(date: point.date, macro: "Carbs", grams: point.carbs, color: .carbsColor),
                MacroStackEntry(date: point.date, macro: "Fat", grams: point.fat, color: .fatColor)
            ]
        }
    }

    private func trendValue(for point: DailyDataPoint) -> Double {
        switch trendSelection {
        case .protein: return point.protein
        case .carbs: return point.carbs
        case .fat: return point.fat
        }
    }

    private func goalTarget(for selection: NutrientTrendSelection, goal: DailyGoal) -> Double {
        switch selection {
        case .protein: return goal.proteinGramsTarget
        case .carbs: return goal.carbsGramsTarget
        case .fat: return goal.fatGramsTarget
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

    // MARK: - Calorie Comparison

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

    // MARK: - Macro Breakdown

    private var macroBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macro Breakdown")
                .font(.headline)

            macroRow(
                label: "Protein",
                grams: day.protein,
                target: goal?.proteinGramsTarget,
                color: .proteinColor
            )

            macroRow(
                label: "Carbs",
                grams: day.carbs,
                target: goal?.carbsGramsTarget,
                color: .carbsColor
            )

            macroRow(
                label: "Fat",
                grams: day.fat,
                target: goal?.fatGramsTarget,
                color: .fatColor
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func macroRow(label: String, grams: Double, target: Double?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(grams.oneDecimalString + "g")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
                if let target = target {
                    Text("/ \(target.oneDecimalString)g")
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
                            .frame(
                                width: geo.size.width * grams.progressRatio(of: target),
                                height: 8
                            )
                    }
                }
                .frame(height: 8)
            }
        }
    }

    // MARK: - Meals List

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
                    Text("P:\(meal.totalProteinGrams.oneDecimalString)")
                        .foregroundStyle(.proteinColor)
                    Text("C:\(meal.totalCarbsGrams.oneDecimalString)")
                        .foregroundStyle(.carbsColor)
                    Text("F:\(meal.totalFatGrams.oneDecimalString)")
                        .foregroundStyle(.fatColor)
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
