import SwiftUI
import SwiftData

struct SmartInsightsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var totalMeals: Int = 0
    @State private var uniqueDays: Int = 0
    @State private var isLoading = true

    private var hasEnoughData: Bool {
        uniqueDays >= 3
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
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
            LazyVStack(spacing: 16) {
                // Summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Based on \(totalMeals) meals over \(uniqueDays) days")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

                Text("More insights coming soon as you log more meals.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    private func loadData() async {
        let context = modelContext
        do {
            let descriptor = FetchDescriptor<Meal>(
                predicate: #Predicate<Meal> { $0.isConfirmedByUser == true }
            )
            let meals = try context.fetch(descriptor)
            let count = meals.count
            let days = Set(meals.map { Calendar.current.startOfDay(for: $0.timestamp) }).count

            await MainActor.run {
                totalMeals = count
                uniqueDays = days
                isLoading = false
            }
        } catch {
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        SmartInsightsView()
            .modelContainer(for: Meal.self, inMemory: true)
    }
}
