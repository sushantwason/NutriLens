import SwiftUI

struct AIConsentView: View {
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "brain.filled.head.profile")
                            .font(.system(size: 44))
                            .foregroundStyle(.nutriPurple)

                        Text("AI-Powered Analysis")
                            .font(.title2.weight(.bold))

                        Text("MealSight uses AI to analyze your meal photos")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)

                    // What happens
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How it works")
                            .font(.headline)

                        consentRow(
                            icon: "camera.fill",
                            color: .nutriGreen,
                            title: "Photo Analysis",
                            detail: "When you scan a meal, your photo is sent to Anthropic's Claude AI for nutritional analysis."
                        )

                        consentRow(
                            icon: "arrow.left.arrow.right",
                            color: .nutriBlue,
                            title: "Data Processing",
                            detail: "The image is processed to estimate calories, protein, carbs, and fat, then the results are returned to your device."
                        )

                        consentRow(
                            icon: "lock.shield.fill",
                            color: .nutriPurple,
                            title: "Privacy",
                            detail: "Anthropic does not use API data to train AI models. Images are not stored beyond what is needed to complete the analysis."
                        )

                        consentRow(
                            icon: "iphone",
                            color: .nutriOrange,
                            title: "Local Storage",
                            detail: "Your meal history, goals, and personal data stay on your device."
                        )
                    }

                    // Disclaimer
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Important")
                            .font(.headline)

                        Text("Nutritional estimates are approximations and may vary from actual values. MealSight is not a medical device and does not provide medical advice. Consult a healthcare professional for dietary guidance.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(Color.nutriOrange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 20)
            }

            // Action buttons
            VStack(spacing: 10) {
                Button {
                    onAccept()
                } label: {
                    Text("I Understand, Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.nutriGreen, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }

                Button {
                    onDecline()
                } label: {
                    Text("Not Now")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.regularMaterial)
        }
    }

    private func consentRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    AIConsentView(
        onAccept: { print("Accepted") },
        onDecline: { print("Declined") }
    )
}
