import SwiftUI

struct CoachInsightCard: View {
    let insight: CoachInsight?
    let isLoading: Bool
    let onRefresh: () -> Void

    var body: some View {
        if isLoading {
            loadingView
        } else if let insight {
            insightView(insight)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Getting your nutrition insight...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Insight

    private func insightView(_ insight: CoachInsight) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Text(insight.emoji)
                    .font(.title2)
                Text("AI Coach")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.nutriPurple)
                Spacer()
                Button {
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Message
            Text(insight.message)
                .font(.subheadline)
                .lineLimit(3)

            // Tip
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundStyle(.nutriOrange)
                    .padding(.top, 1)
                Text(insight.tip)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .background(Color.nutriOrange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
