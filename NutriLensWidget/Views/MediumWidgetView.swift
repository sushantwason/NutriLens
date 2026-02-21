import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let entry: NutritionEntry

    private var calorieProgress: Double {
        guard entry.calorieTarget > 0 else { return 0 }
        return min(entry.calories / entry.calorieTarget, 1.0)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Left: calorie ring
            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.2), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: calorieProgress)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text(String(format: "%.0f", entry.calories))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("/ \(String(format: "%.0f", entry.calorieTarget))")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    Text("kcal")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 86, height: 86)

            // Right: macro bars
            VStack(alignment: .leading, spacing: 8) {
                macroBar(
                    label: "Protein",
                    value: entry.protein,
                    target: entry.proteinTarget,
                    color: .orange
                )
                macroBar(
                    label: "Carbs",
                    value: entry.carbs,
                    target: entry.carbsTarget,
                    color: .blue
                )
                macroBar(
                    label: "Fat",
                    value: entry.fat,
                    target: entry.fatTarget,
                    color: .purple
                )

                HStack(spacing: 4) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 9))
                    Text("\(entry.mealCount) meals today")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private func macroBar(label: String, value: Double, target: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                Spacer()
                Text("\(String(format: "%.0f", value))/\(String(format: "%.0f", target))g")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.2))
                        .frame(height: 6)

                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * min(value / max(target, 1), 1.0), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}
