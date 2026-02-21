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

            Text("Your first scan is just a tap away. Point your camera at a meal, label, or barcode to see NutriLens in action.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

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
}
