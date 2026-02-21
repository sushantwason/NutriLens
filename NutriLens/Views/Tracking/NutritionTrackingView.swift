import SwiftUI
import SwiftData
import Charts

struct NutritionTrackingView: View {
    @Query(filter: #Predicate<Meal> { $0.isConfirmedByUser == true },
           sort: \Meal.timestamp, order: .reverse)
    private var allMeals: [Meal]
    @Query(filter: #Predicate<DailyGoal> { $0.isActive == true }) private var activeGoals: [DailyGoal]
    @Query(sort: \WeightEntry.date) private var weightEntries: [WeightEntry]

    @State private var timeRange: TimeRange = .week

    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            }
        }
    }

    private var summaries: [NutritionCalculator.DailySummary] {
        NutritionCalculator.dailySummaries(from: Array(allMeals), days: timeRange.days)
    }

    private var goal: DailyGoal? { activeGoals.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Time Range", selection: $timeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    calorieBarChart
                    macroTrendChart
                    macroPieChart
                    if !filteredWeightEntries.isEmpty {
                        weightTrendChart
                    }
                }
                .padding()
            }
            .navigationTitle("Tracking")
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Calorie Bar Chart

    private var calorieBarChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Calories")
                .font(.headline)

            Chart(summaries) { summary in
                BarMark(
                    x: .value("Day", summary.date, unit: .day),
                    y: .value("Calories", summary.totalCalories)
                )
                .foregroundStyle(barColor(for: summary.totalCalories))
                .cornerRadius(4)

                if let goal {
                    RuleMark(y: .value("Goal", goal.calorieTarget))
                        .foregroundStyle(.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date.shortDayOfWeek)
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func barColor(for calories: Double) -> Color {
        guard let target = goal?.calorieTarget, target > 0 else { return .calorieColor }
        let ratio = calories / target
        if ratio <= 0.9 { return .nutriGreen }
        if ratio <= 1.1 { return .calorieColor }
        return .nutriRed
    }

    // MARK: - Macro Trend Lines

    private var macroTrendChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Macro Trends")
                .font(.headline)

            Chart {
                ForEach(summaries) { summary in
                    LineMark(
                        x: .value("Day", summary.date, unit: .day),
                        y: .value("Grams", summary.totalProtein),
                        series: .value("Macro", "Protein")
                    )
                    .foregroundStyle(.proteinColor)

                    LineMark(
                        x: .value("Day", summary.date, unit: .day),
                        y: .value("Grams", summary.totalCarbs),
                        series: .value("Macro", "Carbs")
                    )
                    .foregroundStyle(.carbsColor)

                    LineMark(
                        x: .value("Day", summary.date, unit: .day),
                        y: .value("Grams", summary.totalFat),
                        series: .value("Macro", "Fat")
                    )
                    .foregroundStyle(.fatColor)
                }
            }
            .frame(height: 200)
            .chartForegroundStyleScale([
                "Protein": Color.proteinColor,
                "Carbs": Color.carbsColor,
                "Fat": Color.fatColor
            ])
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date.shortDayOfWeek)
                                .font(.caption2)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Macro Pie Chart

    private var macroPieChart: some View {
        let totalProtein = summaries.reduce(0) { $0 + $1.totalProtein }
        let totalCarbs = summaries.reduce(0) { $0 + $1.totalCarbs }
        let totalFat = summaries.reduce(0) { $0 + $1.totalFat }
        let total = totalProtein + totalCarbs + totalFat

        return VStack(alignment: .leading, spacing: 8) {
            Text("Macro Split")
                .font(.headline)

            if total > 0 {
                Chart {
                    SectorMark(angle: .value("Protein", totalProtein), innerRadius: .ratio(0.5))
                        .foregroundStyle(.proteinColor)
                    SectorMark(angle: .value("Carbs", totalCarbs), innerRadius: .ratio(0.5))
                        .foregroundStyle(.carbsColor)
                    SectorMark(angle: .value("Fat", totalFat), innerRadius: .ratio(0.5))
                        .foregroundStyle(.fatColor)
                }
                .frame(height: 200)

                HStack(spacing: 16) {
                    legendItem("Protein", pct: totalProtein / total, color: .proteinColor)
                    legendItem("Carbs", pct: totalCarbs / total, color: .carbsColor)
                    legendItem("Fat", pct: totalFat / total, color: .fatColor)
                }
                .frame(maxWidth: .infinity)
            } else {
                Text("No data for this period")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func legendItem(_ name: String, pct: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(name) \(Int(pct * 100))%")
                .font(.caption)
        }
    }

    // MARK: - Weight Trend

    private var filteredWeightEntries: [WeightEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -timeRange.days, to: Date()) ?? Date()
        return weightEntries.filter { $0.date >= cutoff }
    }

    private var weightTrendChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weight Trend")
                .font(.headline)

            Chart(filteredWeightEntries) { entry in
                LineMark(
                    x: .value("Date", entry.date, unit: .day),
                    y: .value("Weight", entry.weightKG)
                )
                .foregroundStyle(.nutriPurple)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", entry.date, unit: .day),
                    y: .value("Weight", entry.weightKG)
                )
                .foregroundStyle(.nutriPurple)
                .symbolSize(30)
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let kg = value.as(Double.self) {
                            Text("\(kg, specifier: "%.0f") kg")
                                .font(.caption2)
                        }
                    }
                    AxisGridLine()
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NutritionTrackingView()
        .modelContainer(for: [Meal.self, DailyGoal.self, WeightEntry.self], inMemory: true)
}
