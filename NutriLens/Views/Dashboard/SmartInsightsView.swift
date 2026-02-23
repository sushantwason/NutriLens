import SwiftUI
import SwiftData

struct SmartInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<DailyGoal> { $0.isActive == true })
    private var activeGoals: [DailyGoal]

    @State private var insights: [NutritionInsightsEngine.InsightCard] = []
    @State private var totalMeals: Int = 0
    @State private var uniqueDays: Int = 0
    @State private var isLoading = true

    private var hasEnoughData: Bool {
        uniqueDays >= 3
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Analyzing your meals...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !hasEnoughData {
                notEnoughDataView
            } else {
                insightsListView
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadData()
        }
    }

    private var notEnoughDataView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)

            Text("Not Enough Data Yet")
                .font(.title2.weight(.bold))

            Text("Log meals for at least 3–7 days to start seeing patterns, correlations, and smart suggestions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    private var insightsListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Summary header
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile.fill")
                        .font(.body)
                        .foregroundStyle(.nutriPurple)
                    Text("Based on \(totalMeals) meals over \(uniqueDays) days")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

                // Insight cards
                ForEach(insights) { insight in
                    insightCardView(insight)
                }

                if insights.isEmpty {
                    Text("More insights coming soon as you log more meals.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    private func insightCardView(_ insight: NutritionInsightsEngine.InsightCard) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(colorForName(insight.iconColor))
                .frame(width: 36, height: 36)
                .background(colorForName(insight.iconColor).opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(insight.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    severityBadge(insight.severity)
                }
                Text(insight.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func severityBadge(_ severity: NutritionInsightsEngine.Severity) -> some View {
        let (text, color): (String, Color) = switch severity {
        case .alert: ("Alert", .nutriRed)
        case .warning: ("Warning", .nutriOrange)
        case .info: ("Info", .nutriBlue)
        }
        return Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func colorForName(_ name: String) -> Color {
        switch name {
        case "nutriGreen": return .nutriGreen
        case "nutriBlue": return .nutriBlue
        case "nutriOrange": return .nutriOrange
        case "nutriRed": return .nutriRed
        case "nutriPurple": return .nutriPurple
        default: return .secondary
        }
    }

    private func loadData() async {
        let context = modelContext
        let goal = activeGoals.first

        // Count meals/days first
        do {
            let descriptor = FetchDescriptor<Meal>(
                predicate: #Predicate<Meal> { $0.isConfirmedByUser == true }
            )
            let meals = try context.fetch(descriptor)
            let count = meals.count
            let days = Set(meals.map { Calendar.current.startOfDay(for: $0.timestamp) }).count

            totalMeals = count
            uniqueDays = days

            if days >= 3 {
                let generated = await NutritionInsightsEngine.generateInsights(
                    context: context,
                    goal: goal
                )
                insights = generated
            }

            isLoading = false
        } catch {
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        SmartInsightsView()
            .modelContainer(for: [Meal.self, DailyGoal.self], inMemory: true)
    }
}
