import SwiftUI

struct StreakBadgeView: View {
    let currentStreak: Int
    let longestStreak: Int

    var body: some View {
        HStack(spacing: 16) {
            // Current streak
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(currentStreak > 0 ? .nutriOrange : .secondary)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(currentStreak) day\(currentStreak == 1 ? "" : "s")")
                        .font(.subheadline.weight(.bold))
                    Text("Current Streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Longest streak
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .foregroundStyle(longestStreak > 0 ? .nutriPurple : .secondary)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(longestStreak) day\(longestStreak == 1 ? "" : "s")")
                        .font(.subheadline.weight(.bold))
                    Text("Longest Streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
