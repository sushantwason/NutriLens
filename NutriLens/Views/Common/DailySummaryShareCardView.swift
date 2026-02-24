import SwiftUI

/// A branded card showing the entire day's meals with totals, rendered as a shareable image.
struct DailySummaryShareCardView: View {
    let date: Date
    let meals: [MealSummary]
    let totalCalories: Double
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double
    let totalSugar: Double
    let scanStreak: Int

    struct MealSummary: Identifiable {
        let id: UUID
        let name: String
        let mealTypeIcon: String
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with date + streak
            headerSection

            // Macro totals bar
            macroTotalsBar

            // Meal list
            mealListSection

            // Branding footer
            brandingFooter
        }
        .frame(width: 360)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color(red: 0.15, green: 0.68, blue: 0.38))
                Text("MealSight")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color(red: 0.15, green: 0.68, blue: 0.38))
                Spacer()
                if scanStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.15))
                        Text("\(scanStreak)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
            }

            HStack {
                Text(dateLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text("\(meals.count) meal\(meals.count == 1 ? "" : "s")")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(16)
        .background(Color(red: 0.1, green: 0.1, blue: 0.12))
    }

    private var dateLabel: String {
        if date.isToday { return "Today" }
        if date.isYesterday { return "Yesterday" }
        return date.mediumDateString
    }

    // MARK: - Macro Totals

    private var macroTotalsBar: some View {
        VStack(spacing: 8) {
            // Big calorie number
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(totalCalories.calorieString)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("kcal total")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            // Macro pills
            HStack(spacing: 0) {
                macroPill("Protein", totalProtein, "g", Color(red: 0.35, green: 0.55, blue: 0.95))
                macroPill("Carbs", totalCarbs, "g", Color(red: 0.95, green: 0.65, blue: 0.25))
                macroPill("Fat", totalFat, "g", Color(red: 0.9, green: 0.35, blue: 0.35))
                macroPill("Sugar", totalSugar, "g", Color(red: 0.7, green: 0.45, blue: 0.85))
            }
        }
        .padding(.vertical, 14)
        .background(Color(red: 0.12, green: 0.12, blue: 0.14))
    }

    private func macroPill(_ label: String, _ value: Double, _ unit: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value.wholeString + unit)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Meal List

    private var mealListSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(meals.enumerated()), id: \.element.id) { index, meal in
                mealRow(meal)
                if index < meals.count - 1 {
                    Rectangle()
                        .fill(.white.opacity(0.06))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                }
            }
        }
        .background(Color(red: 0.14, green: 0.14, blue: 0.16))
    }

    private func mealRow(_ meal: MealSummary) -> some View {
        HStack(spacing: 10) {
            Image(systemName: meal.mealTypeIcon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(red: 0.15, green: 0.68, blue: 0.38))
                .frame(width: 28, height: 28)
                .background(Color(red: 0.15, green: 0.68, blue: 0.38).opacity(0.15), in: RoundedRectangle(cornerRadius: 6))

            Text(meal.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 4) {
                Text("P:\(meal.protein.wholeString)")
                    .foregroundStyle(Color(red: 0.35, green: 0.55, blue: 0.95))
                Text("C:\(meal.carbs.wholeString)")
                    .foregroundStyle(Color(red: 0.95, green: 0.65, blue: 0.25))
                Text("F:\(meal.fat.wholeString)")
                    .foregroundStyle(Color(red: 0.9, green: 0.35, blue: 0.35))
            }
            .font(.system(size: 9, weight: .medium, design: .rounded))

            Text("\(meal.calories.calorieString)")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(red: 0.95, green: 0.55, blue: 0.15))
                .frame(minWidth: 30, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Branding

    private var brandingFooter: some View {
        HStack {
            Image(systemName: "fork.knife.circle.fill")
                .font(.caption)
                .foregroundStyle(Color(red: 0.15, green: 0.68, blue: 0.38))
            Text("Tracked with MealSight")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.08, green: 0.08, blue: 0.1))
    }
}

// MARK: - Image Rendering

extension DailySummaryShareCardView {
    @MainActor
    func renderImage() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}
