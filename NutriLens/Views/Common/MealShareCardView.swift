import SwiftUI

/// A branded card rendered as a shareable image for a meal.
struct MealShareCardView: View {
    let mealName: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let sugar: Double
    let mealTypeIcon: String
    let mealPhoto: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            // Photo or gradient header
            ZStack(alignment: .bottomLeading) {
                if let photo = mealPhoto {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipped()
                        .overlay {
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.7)],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                        }
                } else {
                    LinearGradient(
                        colors: [Color(red: 0.15, green: 0.68, blue: 0.38), Color(red: 0.1, green: 0.5, blue: 0.28)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 160)
                }

                // Meal name overlay
                VStack(alignment: .leading, spacing: 4) {
                    Text(mealName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(calories.calorieString)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("kcal")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(16)
            }

            // Macro bar
            HStack(spacing: 0) {
                macroPill("Protein", protein, "g", Color(red: 0.35, green: 0.55, blue: 0.95))
                macroPill("Carbs", carbs, "g", Color(red: 0.95, green: 0.65, blue: 0.25))
                macroPill("Fat", fat, "g", Color(red: 0.9, green: 0.35, blue: 0.35))
                macroPill("Sugar", sugar, "g", Color(red: 0.7, green: 0.45, blue: 0.85))
            }
            .padding(.vertical, 12)
            .background(Color(red: 0.12, green: 0.12, blue: 0.14))

            // Branding footer
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
        .frame(width: 360)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
}

// MARK: - Image Rendering

extension MealShareCardView {
    @MainActor
    func renderImage() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}
