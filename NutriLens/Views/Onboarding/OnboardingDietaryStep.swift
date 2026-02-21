import SwiftUI

struct OnboardingDietaryStep: View {
    @Binding var dietaryRestrictions: Set<DietaryRestriction>
    let onNext: () -> Void
    let onSkip: () -> Void

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                Image(systemName: "leaf.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.nutriGreen)

                Text("Dietary Preferences")
                    .font(.title2.weight(.bold))

                Text("Select any dietary restrictions so we can alert you about potential concerns.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Restriction grid
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(DietaryRestriction.allCases) { restriction in
                    restrictionToggle(restriction)
                }
            }
            .padding(.horizontal)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button {
                    onNext()
                } label: {
                    Text(dietaryRestrictions.isEmpty ? "None of These" : "Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.nutriGreen, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }

                Button("Skip") {
                    onSkip()
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 20)
        }
    }

    private func restrictionToggle(_ restriction: DietaryRestriction) -> some View {
        let isSelected = dietaryRestrictions.contains(restriction)
        return Button {
            if isSelected {
                dietaryRestrictions.remove(restriction)
            } else {
                dietaryRestrictions.insert(restriction)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: restriction.icon)
                    .font(.caption)
                Text(restriction.displayName)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(
                isSelected ? Color.nutriGreen.opacity(0.15) : Color(.systemGray6),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.nutriGreen : .clear, lineWidth: 2)
            )
            .foregroundStyle(isSelected ? .nutriGreen : .primary)
        }
        .buttonStyle(.plain)
    }
}
