import SwiftUI

struct RemainingBudgetCard: View {
    let budget: MealSuggestionService.RemainingBudget
    let suggestion: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Remaining Today")
                .font(.headline)

            HStack(spacing: 8) {
                budgetPill("Cal", value: budget.calories, unit: "kcal", color: .calorieColor)
                budgetPill("P", value: budget.proteinGrams, unit: "g", color: .proteinColor)
                budgetPill("C", value: budget.carbsGrams, unit: "g", color: .carbsColor)
                budgetPill("F", value: budget.fatGrams, unit: "g", color: .fatColor)
            }

            if let suggestion {
                Divider()
                Label {
                    Text(suggestion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.nutriOrange)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func budgetPill(_ label: String, value: Double, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value.oneDecimalString)
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}
