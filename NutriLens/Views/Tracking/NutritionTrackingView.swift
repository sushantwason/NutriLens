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
                VStack(spacing: 16) {
                    Picker("Time Range", selection: $timeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    calorieBarChart
                    macroSplitCard
                    if !filteredWeightEntries.isEmpty {
                        weightTrendChart
                    }

                    reportLinksSection
                }
                .padding()
            }
            .navigationTitle("Tracking")
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Report Links

    private var reportLinksSection: some View {
        VStack(spacing: 12) {
            NavigationLink {
                InteractiveChartsView()
            } label: {
                reportLinkRow(
                    icon: "chart.xyaxis.line",
                    color: .nutriOrange,
                    title: "Detailed Charts",
                    subtitle: "Macro breakdown and nutrient trends"
                )
            }

        }
    }

    private func reportLinkRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Calorie Bar Chart

    private var calorieBarChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Daily Calories")
                    .font(.headline)
                Spacer()
                if !summaries.isEmpty {
                    let avg = summaries.reduce(0.0) { $0 + $1.totalCalories } / Double(max(summaries.count, 1))
                    Text("Avg: \(Int(avg)) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

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
            .frame(height: 180)
            .chartXAxis {
                if timeRange == .week {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date.shortDayOfWeek)
                                    .font(.caption2)
                            }
                        }
                    }
                } else {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date.shortDateLabel)
                                    .font(.caption2)
                            }
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

    // MARK: - Compact Macro Split

    private var macroSplitCard: some View {
        let totalProtein = summaries.reduce(0) { $0 + $1.totalProtein }
        let totalCarbs = summaries.reduce(0) { $0 + $1.totalCarbs }
        let totalFat = summaries.reduce(0) { $0 + $1.totalFat }
        let totalSugar = summaries.reduce(0) { $0 + $1.totalSugar }
        let total = totalProtein + totalCarbs + totalFat

        return VStack(alignment: .leading, spacing: 10) {
            Text("Macro Split")
                .font(.headline)

            if total > 0 {
                HStack(spacing: 16) {
                    // Compact donut
                    Chart {
                        SectorMark(angle: .value("Protein", totalProtein), innerRadius: .ratio(0.6))
                            .foregroundStyle(.proteinColor)
                        SectorMark(angle: .value("Carbs", totalCarbs), innerRadius: .ratio(0.6))
                            .foregroundStyle(.carbsColor)
                        SectorMark(angle: .value("Fat", totalFat), innerRadius: .ratio(0.6))
                            .foregroundStyle(.fatColor)
                    }
                    .frame(width: 100, height: 100)

                    // Macro stats
                    VStack(alignment: .leading, spacing: 8) {
                        macroStatRow("Protein", grams: totalProtein, total: total, color: .proteinColor, target: goal?.proteinGramsTarget)
                        macroStatRow("Carbs", grams: totalCarbs, total: total, color: .carbsColor, target: goal?.carbsGramsTarget)
                        macroStatRow("Fat", grams: totalFat, total: total, color: .fatColor, target: goal?.fatGramsTarget)
                        macroStatRow("Sugar", grams: totalSugar, total: total, color: .sugarColor, target: goal?.sugarGramsTarget)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                Text("No data for this period")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func macroStatRow(_ name: String, grams: Double, total: Double, color: Color, target: Double?) -> some View {
        let days = Double(max(summaries.count, 1))
        let avgPerDay = grams / days
        let pct = Int((grams / total) * 100)

        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(name)
                        .font(.caption.weight(.medium))
                    Text("\(pct)%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("\(Int(avgPerDay))g/day avg")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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
            .frame(height: 150)
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
