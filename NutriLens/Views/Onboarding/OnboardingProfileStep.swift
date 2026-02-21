import SwiftUI

struct OnboardingProfileStep: View {
    @Binding var heightCM: Double
    @Binding var weightKG: Double
    @Binding var age: Double
    @Binding var biologicalSex: BiologicalSex
    @Binding var activityLevel: ActivityLevel
    let onNext: () -> Void
    let onSkip: () -> Void

    private var bmi: Double {
        let heightM = heightCM / 100.0
        guard heightM > 0 else { return 0 }
        return weightKG / (heightM * heightM)
    }

    private var bmiCategory: String {
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Normal"
        case 25..<30: return "Overweight"
        default: return "Obese"
        }
    }

    private var bmiColor: Color {
        switch bmi {
        case ..<18.5: return .nutriOrange
        case 18.5..<25: return .nutriGreen
        case 25..<30: return .nutriOrange
        default: return .nutriRed
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "figure.stand")
                        .font(.system(size: 48))
                        .foregroundStyle(.nutriBlue)

                    Text("Your Profile")
                        .font(.title.bold())

                    Text("Help us calculate personalized nutrition goals based on your body metrics.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)

                // BMI Badge
                HStack(spacing: 8) {
                    Text("BMI")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", bmi))
                        .font(.title3.weight(.bold))
                    Text(bmiCategory)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(bmiColor, in: Capsule())
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Sliders
                VStack(spacing: 16) {
                    sliderRow(
                        value: $heightCM,
                        range: 140...220,
                        step: 1,
                        label: "Height",
                        valueText: "\(Int(heightCM)) cm",
                        color: .nutriBlue
                    )

                    sliderRow(
                        value: $weightKG,
                        range: 40...200,
                        step: 0.5,
                        label: "Weight",
                        valueText: "\(weightKG.oneDecimalString) kg",
                        color: .nutriBlue
                    )

                    sliderRow(
                        value: $age,
                        range: 15...80,
                        step: 1,
                        label: "Age",
                        valueText: "\(Int(age)) years",
                        color: .nutriBlue
                    )
                }
                .padding(.horizontal)

                // Pickers
                VStack(spacing: 12) {
                    HStack {
                        Text("Biological Sex")
                            .font(.subheadline)
                        Spacer()
                        Picker("Sex", selection: $biologicalSex) {
                            ForEach(BiologicalSex.allCases) { sex in
                                Text(sex.displayName).tag(sex)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 200)
                    }
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Activity Level")
                            .font(.subheadline)
                        Picker("Activity", selection: $activityLevel) {
                            ForEach(ActivityLevel.allCases) { level in
                                Text(level.displayName).tag(level)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.nutriBlue)

                        Text(activityLevel.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

                // Buttons
                VStack(spacing: 12) {
                    Button(action: onNext) {
                        Text("Calculate My Goals")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.nutriGreen, in: RoundedRectangle(cornerRadius: 14))
                    }

                    Button(action: onSkip) {
                        Text("Skip, I'll set goals manually")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
    }

    private func sliderRow(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        label: String,
        valueText: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(valueText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
            }

            Slider(value: value, in: range, step: step)
                .tint(color)
        }
    }
}
