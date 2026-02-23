import SwiftUI
import SwiftData
import Charts

struct WeeklyReportView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<DailyGoal> { $0.isActive == true })
    private var activeGoals: [DailyGoal]

    @State private var cachedComparison: WeekComparison?
    @State private var isLoading = true

    private var comparison: WeekComparison {
        cachedComparison ?? WeeklyReportCalculator.generateComparison(meals: [])
    }

    private var report: WeeklyReport {
        comparison.currentWeek
    }

    private var goal: DailyGoal? {
        activeGoals.first
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
                VStack(spacing: 16) {
                    weekHeader
                    dailyAveragesCard
                    weekComparisonCard
                    dailyChartCard
                    highlightsCard
                }
                .padding()
            }
        }
        .navigationTitle("Weekly Report")
        .background(Color(.systemGroupedBackground))
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        let context = modelContext
        let meals: [Meal]
        do {
            var descriptor = FetchDescriptor<Meal>(
                predicate: #Predicate<Meal> { $0.isConfirmedByUser == true },
                sortBy: [SortDescriptor(\Meal.timestamp, order: .reverse)]
            )
            // Only need last 2 weeks for comparison
            let cutoff = Calendar.current.date(byAdding: .weekOfYear, value: -2, to: Date()) ?? Date()
            descriptor.predicate = #Predicate<Meal> { $0.isConfirmedByUser == true && $0.timestamp >= cutoff }
            meals = try context.fetch(descriptor)
        } catch {
            isLoading = false
            return
        }

        let result = WeeklyReportCalculator.generateComparison(meals: meals)

        await MainActor.run {
            cachedComparison = result
            isLoading = false
        }
    }

    // MARK: - Week Header

    private var weekHeader: some View {
        VStack(spacing: 6) {
            Text(weekRangeString)
                .font(.headline)

            HStack(spacing: 16) {
                statPill(label: "Meals", value: "\(report.totalMeals)")
                statPill(label: "Active Days", value: "\(report.activeDays)/7")
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var weekRangeString: String {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        let start = df.string(from: report.weekStart)
        let end = df.string(from: Calendar.current.date(byAdding: .day, value: -1, to: report.weekEnd) ?? report.weekEnd)
        return "\(start) – \(end)"
    }

    private func statPill(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Daily Averages

    private var dailyAveragesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Averages")
                .font(.headline)

            HStack(spacing: 12) {
                averagePill("Calories", value: report.avgCalories, unit: "kcal", color: .calorieColor)
                averagePill("Protein", value: report.avgProtein, unit: "g", color: .proteinColor)
                averagePill("Carbs", value: report.avgCarbs, unit: "g", color: .carbsColor)
                averagePill("Fat", value: report.avgFat, unit: "g", color: .fatColor)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func averagePill(_ label: String, value: Double, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%.0f", value))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Week Comparison

    private var weekComparisonCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("vs Last Week")
                .font(.headline)

            HStack(spacing: 12) {
                changeRow("Calories", change: comparison.calorieChange, color: .calorieColor)
                changeRow("Protein", change: comparison.proteinChange, color: .proteinColor)
                changeRow("Carbs", change: comparison.carbsChange, color: .carbsColor)
                changeRow("Fat", change: comparison.fatChange, color: .fatColor)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func changeRow(_ label: String, change: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
                Text(String(format: "%.0f%%", abs(change)))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(color)

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Daily Chart

    private var dailyChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Breakdown")
                .font(.headline)

            Chart {
                ForEach(report.dailySummaries) { summary in
                    BarMark(
                        x: .value("Day", summary.date, unit: .day),
                        y: .value("Calories", summary.totalCalories)
                    )
                    .foregroundStyle(.calorieColor.gradient)
                    .cornerRadius(4)
                }

                if let calorieTarget = goal?.calorieTarget {
                    RuleMark(y: .value("Goal", calorieTarget))
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
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks { value in
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

    // MARK: - Highlights

    private var highlightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Highlights")
                .font(.headline)

            if let highest = report.highestCalorieDay {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.nutriOrange)
                    VStack(alignment: .leading) {
                        Text("Highest Day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(highest.date.shortDayOfWeek) — \(String(format: "%.0f", highest.totalCalories)) kcal")
                            .font(.subheadline.weight(.medium))
                    }
                    Spacer()
                }
            }

            if let lowest = report.lowestCalorieDay, report.activeDays > 1 {
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(.nutriGreen)
                    VStack(alignment: .leading) {
                        Text("Lowest Day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(lowest.date.shortDayOfWeek) — \(String(format: "%.0f", lowest.totalCalories)) kcal")
                            .font(.subheadline.weight(.medium))
                    }
                    Spacer()
                }
            }

            if report.totalMeals == 0 {
                Text("No meals logged this week yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        WeeklyReportView()
    }
    .modelContainer(for: [Meal.self, DailyGoal.self], inMemory: true)
}
