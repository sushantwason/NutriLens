import SwiftUI

/// A dismissible card prompting users to add MealSight widgets to their home / lock screen.
struct WidgetUpsellCard: View {
    @AppStorage("mealsight.widget.upsell.dismissed") private var isDismissed = false

    var body: some View {
        if !isDismissed {
            cardContent
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.title3)
                    .foregroundStyle(.nutriGreen)
                    .frame(width: 36, height: 36)
                    .background(.nutriGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Add MealSight Widget")
                        .font(.subheadline.weight(.semibold))
                    Text("See calories & macros right from your home screen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.25)) {
                        isDismissed = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 24, height: 24)
                        .background(.quaternary, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss widget suggestion")
            }

            // How-to instruction
            HStack(spacing: 6) {
                Image(systemName: "hand.tap.fill")
                    .font(.caption)
                    .foregroundStyle(.nutriGreen)
                Text("Long-press your home screen \u{2192} tap \u{FF0B} \u{2192} search MealSight")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(Color.nutriGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Add MealSight Widget. See calories and macros right from your home screen.")
        .accessibilityHint("Long-press your home screen, tap plus, and search MealSight to add a widget")
    }
}
