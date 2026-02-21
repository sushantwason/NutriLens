import SwiftUI
import WidgetKit

struct LockScreenRectangularView: View {
    let entry: NutritionEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 10))
                Text("NutriLens")
                    .font(.system(size: 11, weight: .semibold))
            }

            Text("\(String(format: "%.0f", entry.calories)) / \(String(format: "%.0f", entry.calorieTarget)) kcal")
                .font(.system(size: 13, weight: .bold, design: .rounded))

            HStack(spacing: 6) {
                Text("P:\(String(format: "%.0f", entry.protein))g")
                Text("C:\(String(format: "%.0f", entry.carbs))g")
                Text("F:\(String(format: "%.0f", entry.fat))g")
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)
        }
    }
}
