import SwiftUI
import WidgetKit

struct LockScreenCircularView: View {
    let entry: NutritionEntry

    private var calorieProgress: Double {
        guard entry.calorieTarget > 0 else { return 0 }
        return min(entry.calories / entry.calorieTarget, 1.0)
    }

    var body: some View {
        Gauge(value: calorieProgress) {
            Image(systemName: "fork.knife")
        } currentValueLabel: {
            Text(String(format: "%.0f", entry.calories))
                .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
    }
}
