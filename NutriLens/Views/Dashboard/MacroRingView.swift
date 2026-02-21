import SwiftUI

struct MacroRingView<Content: View>: View {
    let progress: Double
    let color: Color
    var lineWidth: CGFloat = 12
    var size: CGFloat = 100
    @ViewBuilder let content: () -> Content

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: clampedProgress)

            // Center content
            content()
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 20) {
        MacroRingView(progress: 0.65, color: .calorieColor, lineWidth: 16, size: 120) {
            VStack {
                Text("1300")
                    .font(.title2.bold())
                Text("/ 2000")
                    .font(.caption)
            }
        }

        MacroRingView(progress: 0.4, color: .proteinColor, lineWidth: 8, size: 60) {
            Text("60g")
                .font(.caption.bold())
        }
    }
}
