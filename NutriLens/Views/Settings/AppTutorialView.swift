import SwiftUI

struct AppTutorialView: View {
    var body: some View {
        List {
            Section("Getting Started") {
                tutorialRow(
                    icon: "camera.fill",
                    title: "Scan a Meal",
                    description: "Tap the Scan Meal button on the Dashboard. Point your camera at any meal, nutrition label, or barcode.",
                    color: .nutriGreen
                )
                tutorialRow(
                    icon: "checkmark.circle.fill",
                    title: "Confirm & Save",
                    description: "Review the AI analysis, adjust any items if needed, then tap Save to log the meal.",
                    color: .nutriBlue
                )
                tutorialRow(
                    icon: "chart.pie.fill",
                    title: "Track Progress",
                    description: "View your daily calories, macros, and trends on the Dashboard and Tracking tabs.",
                    color: .nutriOrange
                )
            }

            Section("Features") {
                tutorialRow(
                    icon: "target",
                    title: "Set Daily Goals",
                    description: "Go to Settings > Daily Goals to set your calorie and macro targets.",
                    color: .nutriPurple
                )
                tutorialRow(
                    icon: "drop.fill",
                    title: "Water Tracking",
                    description: "Log your water intake directly from the Dashboard to stay hydrated.",
                    color: .nutriBlue
                )
                tutorialRow(
                    icon: "scalemass.fill",
                    title: "Weight Log",
                    description: "Track your weight over time in Settings > Weight Log.",
                    color: .nutriGreen
                )
                tutorialRow(
                    icon: "heart.fill",
                    title: "Apple Health",
                    description: "Sync your nutrition and water data with Apple Health in Settings.",
                    color: .nutriRed
                )
                tutorialRow(
                    icon: "clock.fill",
                    title: "Meal History",
                    description: "View all your past meals in the History tab. Swipe to favorite, re-log, or delete meals.",
                    color: .calorieColor
                )
            }

            Section("Tips") {
                tutorialRow(
                    icon: "lightbulb.fill",
                    title: "Better Scans",
                    description: "For best results, photograph your meal from above with good lighting. Include all items in the frame.",
                    color: .nutriOrange
                )
                tutorialRow(
                    icon: "barcode.viewfinder",
                    title: "Barcode Scanning",
                    description: "Point your camera at a product barcode for instant nutrition data from the product database.",
                    color: .nutriGreen
                )
                tutorialRow(
                    icon: "hand.thumbsup.fill",
                    title: "Accuracy Feedback",
                    description: "After each scan, rate the accuracy to help improve future results.",
                    color: .nutriBlue
                )
            }
        }
        .navigationTitle("App Tutorial")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tutorialRow(icon: String, title: String, description: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        AppTutorialView()
    }
}
