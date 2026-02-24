import SwiftUI

struct OnboardingGoalStep: View {
    @Binding var calorieTarget: Double
    @Binding var proteinTarget: Double
    @Binding var carbsTarget: Double
    @Binding var fatTarget: Double
    @Binding var sugarTarget: Double
    let onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Set Your Daily Goals")
                        .font(.title.bold())
                    Text("You can adjust these anytime in Settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                goalSlider(
                    label: "Calories",
                    value: $calorieTarget,
                    range: 1000...4000,
                    step: 50,
                    unit: "kcal",
                    color: .calorieColor
                )

                goalSlider(
                    label: "Protein",
                    value: $proteinTarget,
                    range: 30...300,
                    step: 5,
                    unit: "g",
                    color: .proteinColor
                )

                goalSlider(
                    label: "Carbs",
                    value: $carbsTarget,
                    range: 50...500,
                    step: 5,
                    unit: "g",
                    color: .carbsColor
                )

                goalSlider(
                    label: "Fat",
                    value: $fatTarget,
                    range: 20...200,
                    step: 5,
                    unit: "g",
                    color: .fatColor
                )

                goalSlider(
                    label: "Sugar",
                    value: $sugarTarget,
                    range: 10...150,
                    step: 5,
                    unit: "g",
                    color: .sugarColor
                )

                Button(action: onNext) {
                    Text("Next")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.nutriGreen, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
        }
    }

    private func goalSlider(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label)
                Spacer()
                Text("\(value.wrappedValue.oneDecimalString) \(unit)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
            }
            Slider(value: value, in: range, step: step)
                .tint(color)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
