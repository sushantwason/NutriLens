import SwiftUI

struct AccuracyFeedbackBanner: View {
    let onRate: (Int) -> Void
    @State private var hasRated = false

    var body: some View {
        if !hasRated {
            VStack(spacing: 8) {
                Text("How accurate was this analysis?")
                    .font(.subheadline.weight(.medium))

                HStack(spacing: 24) {
                    Button {
                        onRate(0)
                        withAnimation { hasRated = true }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "hand.thumbsdown.fill")
                                .font(.title2)
                            Text("Inaccurate")
                                .font(.caption)
                        }
                        .foregroundStyle(.nutriRed)
                    }

                    Button {
                        onRate(1)
                        withAnimation { hasRated = true }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.title2)
                            Text("Accurate")
                                .font(.caption)
                        }
                        .foregroundStyle(.nutriGreen)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.nutriGreen)
                Text("Thanks for your feedback!")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
            .transition(.opacity)
        }
    }
}
