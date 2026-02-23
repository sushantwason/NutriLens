import SwiftUI

struct AppTutorialView: View {
    var body: some View {
        List {
            Section("Getting Started") {
                tutorialRow(
                    icon: "camera.fill",
                    title: "Scan a Meal",
                    description: "Tap the Scan Meal button on the Dashboard. Point your camera at any meal, nutrition label, or recipe.",
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

            Section("Photo Tips for Best Results") {
                tutorialRow(
                    icon: "light.max",
                    title: "Good Lighting",
                    description: "Natural daylight gives the best results. Avoid harsh shadows or very dim environments — the AI needs to clearly see each item.",
                    color: .nutriOrange
                )
                tutorialRow(
                    icon: "arrow.up.circle.fill",
                    title: "Shoot from Above",
                    description: "A top-down angle (bird's eye view) lets the AI see every item on your plate and better estimate portion sizes.",
                    color: .nutriGreen
                )
                tutorialRow(
                    icon: "arrow.left.and.right.circle.fill",
                    title: "Fill the Frame",
                    description: "Get close enough so the food fills most of the photo. Avoid too much empty space around the plate.",
                    color: .nutriBlue
                )
                tutorialRow(
                    icon: "eye.fill",
                    title: "Show All Items",
                    description: "Spread items out so nothing is hidden or stacked. The AI can only analyze what it can see — uncover toppings and sides.",
                    color: .nutriPurple
                )
                tutorialRow(
                    icon: "hand.raised.fill",
                    title: "Keep It Steady",
                    description: "Hold your phone still while capturing. A blurry photo makes it harder for the AI to identify foods accurately.",
                    color: .calorieColor
                )
                tutorialRow(
                    icon: "circle.dashed",
                    title: "Use a Plate for Scale",
                    description: "Plates and bowls help the AI estimate portions. Food on a standard plate is easier to measure than food in your hand.",
                    color: .nutriGreen
                )
                tutorialRow(
                    icon: "exclamationmark.triangle.fill",
                    title: "Avoid Obstructions",
                    description: "Keep utensils, napkins, and hands out of the way. A clear view of just the food gives the most accurate analysis.",
                    color: .nutriRed
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

            Section("More Tips") {
                tutorialRow(
                    icon: "barcode.viewfinder",
                    title: "Barcode Scanning",
                    description: "Point your camera at a product barcode for instant nutrition data from the product database.",
                    color: .nutriGreen
                )
                tutorialRow(
                    icon: "doc.text.viewfinder",
                    title: "Nutrition Labels",
                    description: "Switch to Label mode to scan packaged food labels. The AI reads serving size, calories, and all macros automatically.",
                    color: .nutriBlue
                )
                tutorialRow(
                    icon: "book.fill",
                    title: "Recipe Scanning",
                    description: "Switch to Recipe mode to scan a recipe from a cookbook, website, or handwritten note. Get per-serving nutrition breakdowns.",
                    color: .nutriOrange
                )
                tutorialRow(
                    icon: "hand.thumbsup.fill",
                    title: "Accuracy Feedback",
                    description: "After each scan, rate the accuracy to help improve future results.",
                    color: .nutriPurple
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
