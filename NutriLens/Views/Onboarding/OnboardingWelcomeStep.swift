import SwiftUI

struct OnboardingWelcomeStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Hero icon
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(.nutriGreen)

            // Punchy tagline
            Text("Snap. Scan. Track.")
                .font(.largeTitle.bold())

            Text("Point your camera at any meal, nutrition label, or barcode \u{2014} MealSight instantly breaks down the calories, protein, carbs, and fat.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            // Feature pills
            VStack(spacing: 12) {
                featurePill(
                    icon: "camera.fill",
                    title: "Meal Photos",
                    subtitle: "AI identifies foods & estimates nutrients"
                )
                featurePill(
                    icon: "doc.text.viewfinder",
                    title: "Nutrition Labels",
                    subtitle: "Instant OCR reads every value"
                )
                featurePill(
                    icon: "barcode.viewfinder",
                    title: "Barcodes",
                    subtitle: "Scan any product for full nutrition facts"
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            Button(action: onNext) {
                Text("Get Started")
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

    private func featurePill(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.nutriGreen)
                .frame(width: 36, height: 36)
                .background(.nutriGreen.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
