import SwiftUI
import SwiftData

struct GoalEditorView: View {
    @Bindable var goal: DailyGoal
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var profile: UserProfile?
    @State private var didLoad = false

    var body: some View {
        List {
            // MARK: - Recalculate from Profile
            if let profile {
                Section {
                    Button {
                        let rec = TDEECalculator.recommendGoals(profile: profile)
                        goal.calorieTarget = rec.calories
                        goal.proteinGramsTarget = rec.proteinGrams
                        goal.carbsGramsTarget = rec.carbsGrams
                        goal.fatGramsTarget = rec.fatGrams
                        goal.sugarGramsTarget = rec.sugarGrams
                    } label: {
                        Label("Recalculate from Profile", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }

            Section("Calories") {
                sliderRow(
                    value: $goal.calorieTarget,
                    range: 1000...4000,
                    step: 50,
                    label: "Daily Calories",
                    unit: "kcal",
                    color: .calorieColor
                )
            }

            Section("Macronutrients") {
                sliderRow(
                    value: $goal.proteinGramsTarget,
                    range: 30...300,
                    step: 5,
                    label: "Protein",
                    unit: "g",
                    color: .proteinColor
                )

                sliderRow(
                    value: $goal.carbsGramsTarget,
                    range: 50...500,
                    step: 5,
                    label: "Carbs",
                    unit: "g",
                    color: .carbsColor
                )

                sliderRow(
                    value: $goal.fatGramsTarget,
                    range: 20...200,
                    step: 5,
                    label: "Fat",
                    unit: "g",
                    color: .fatColor
                )

                sliderRow(
                    value: $goal.sugarGramsTarget,
                    range: 10...150,
                    step: 5,
                    label: "Sugar",
                    unit: "g",
                    color: .sugarColor
                )
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Macro Calories Breakdown")
                        .font(.caption.weight(.medium))
                    let proteinCal = goal.proteinGramsTarget * 4
                    let carbsCal = goal.carbsGramsTarget * 4
                    let fatCal = goal.fatGramsTarget * 9
                    let totalCal = proteinCal + carbsCal + fatCal
                    Text("Protein: \(proteinCal.calorieString) + Carbs: \(carbsCal.calorieString) + Fat: \(fatCal.calorieString) = \(totalCal.calorieString) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

        }
        .navigationTitle("Edit Goals")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !didLoad else { return }
            didLoad = true
            let descriptor = FetchDescriptor<UserProfile>()
            profile = try? modelContext.fetch(descriptor).first
        }
    }

    private func sliderRow(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        label: String,
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
    }
}
