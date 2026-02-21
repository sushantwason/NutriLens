import SwiftUI

struct FoodItemEditRow: View {
    @Binding var item: EditableFoodItem

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 8) {
                nutrientField("Calories", value: $item.calories, unit: "kcal")
                nutrientField("Protein", value: $item.proteinGrams, unit: "g")
                nutrientField("Carbs", value: $item.carbsGrams, unit: "g")
                nutrientField("Fat", value: $item.fatGrams, unit: "g")
                nutrientField("Fiber", value: $item.fiberGrams, unit: "g")
                nutrientField("Sugar", value: $item.sugarGrams, unit: "g")
            }
            .padding(.vertical, 4)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Food name", text: $item.name)
                    .font(.subheadline.weight(.medium))

                HStack {
                    TextField("Quantity", text: $item.quantity)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(item.calories.calorieString) kcal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.calorieColor)
                }
            }
        }
    }

    private func nutrientField(_ name: String, value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(name)
                .font(.caption)
                .frame(width: 60, alignment: .leading)
            TextField("0", value: value, format: .number.precision(.fractionLength(1)))
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
