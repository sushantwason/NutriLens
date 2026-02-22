import SwiftUI

struct FoodItemEditRow: View {
    @Binding var item: EditableFoodItem

    @State private var isExpanded = false

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            LazyVGrid(columns: columns, spacing: 8) {
                nutrientField("Calories", value: $item.calories, unit: "kcal", color: .calorieColor)
                nutrientField("Protein", value: $item.proteinGrams, unit: "g", color: .proteinColor)
                nutrientField("Carbs", value: $item.carbsGrams, unit: "g", color: .carbsColor)
                nutrientField("Fat", value: $item.fatGrams, unit: "g", color: .fatColor)
                nutrientField("Fiber", value: $item.fiberGrams, unit: "g", color: .secondary)
                nutrientField("Sugar", value: $item.sugarGrams, unit: "g", color: .secondary)
            }
            .padding(.vertical, 4)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Food name", text: $item.name)
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 6) {
                    TextField("Quantity", text: $item.quantity)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    macroBadge("P", item.proteinGrams, .proteinColor)
                    macroBadge("C", item.carbsGrams, .carbsColor)
                    macroBadge("F", item.fatGrams, .fatColor)

                    Text("\(item.calories.calorieString) kcal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.calorieColor)
                }
            }
        }
    }

    private func macroBadge(_ letter: String, _ value: Double, _ color: Color) -> some View {
        Text("\(letter):\(value.oneDecimalString)")
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(color)
    }

    private func nutrientField(_ name: String, value: Binding<Double>, unit: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(name)
                .font(.caption2)
                .lineLimit(1)
            Spacer(minLength: 2)
            TextField("0", value: value, format: .number.precision(.fractionLength(1)))
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .font(.caption2)
                .frame(maxWidth: 52)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
