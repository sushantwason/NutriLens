import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: NutritionEntry

    private var calorieProgress: Double {
        guard entry.calorieTarget > 0 else { return 0 }
        return min(entry.calories / entry.calorieTarget, 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Calorie ring
            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: calorieProgress)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text(String(format: "%.0f", entry.calories))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("kcal")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 72, height: 72)

            // Meal count
            HStack(spacing: 4) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 9))
                Text("\(entry.mealCount) meals")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(.secondary)
        }
    }
}
