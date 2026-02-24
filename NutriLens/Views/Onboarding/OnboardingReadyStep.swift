import SwiftUI

struct OnboardingReadyStep: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "camera.fill")
                .font(.system(size: 80))
                .foregroundStyle(.nutriGreen)

            Text("Ready to Scan!")
                .font(.largeTitle.bold())

            Text("Your first scan is just a tap away. Point your camera at a meal, label, or barcode to see MealSight in action.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Widget suggestion
            widgetSuggestionCard
                .padding(.horizontal, 24)

            Spacer()

            Button(action: onFinish) {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                    Text("Start Scanning")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.nutriGreen, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Widget Suggestion

    private var widgetSuggestionCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.title3)
                .foregroundStyle(.nutriGreen)
                .frame(width: 36, height: 36)
                .background(.nutriGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("Add a Widget")
                    .font(.subheadline.weight(.semibold))
                Text("Track nutrition right from your home screen")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tip: Add a MealSight widget to track nutrition from your home screen")
    }
}
