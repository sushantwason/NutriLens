import SwiftUI

struct CoachInsightCard: View {
    let insight: CoachInsight?
    let isLoading: Bool
    let onRefresh: () -> Void

    var body: some View {
        if isLoading {
            loadingView
        } else if let insight {
            insightView(insight)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Getting your nutrition insight...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Insight

    private func insightView(_ insight: CoachInsight) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text(insight.emoji)
                    .font(.title2)
                Text("AI Coach")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.nutriPurple)
                Spacer()
            }

            // Message
            Text(insight.message)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            // Tip
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(.nutriOrange)
                    .padding(.top, 1)
                Text(insight.tip)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .background(Color.nutriOrange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

            // Meal suggestion
            if let suggestion = insight.mealSuggestion {
                mealSuggestionView(suggestion)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Meal Suggestion

    private func mealSuggestionView(_ suggestion: MealSuggestion) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.title3)
                .foregroundStyle(.nutriGreen)

            VStack(alignment: .leading, spacing: 3) {
                Text("Try This")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.nutriGreen)
                    .textCase(.uppercase)

                Text(suggestion.name)
                    .font(.subheadline.weight(.semibold))

                Text(suggestion.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if suggestion.estimatedCalories > 0 {
                    Text("~\(suggestion.estimatedCalories) kcal")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.calorieColor)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.nutriGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}
