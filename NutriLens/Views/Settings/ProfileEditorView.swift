import SwiftUI
import SwiftData

struct ProfileEditorView: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var modelContext

    @State private var goal: DailyGoal?
    @State private var recommendation: TDEECalculator.GoalRecommendation?
    @State private var didLoad = false

    private var bmiColor: Color {
        switch profile.bmi {
        case ..<18.5: return .nutriOrange
        case 18.5..<25: return .nutriGreen
        case 25..<30: return .nutriOrange
        default: return .nutriRed
        }
    }

    private func refreshRecommendation() {
        recommendation = TDEECalculator.recommendGoals(profile: profile)
    }

    var body: some View {
        List {
            // MARK: - Body Measurements
            Section("Body Measurements") {
                sliderRow(
                    value: Binding(
                        get: { profile.heightCM },
                        set: {
                            profile.heightCM = $0
                            profile.updatedDate = Date()
                            refreshRecommendation()
                        }
                    ),
                    range: 140...220,
                    step: 1,
                    label: "Height",
                    valueText: "\(Int(profile.heightCM)) cm",
                    color: .nutriBlue
                )

                sliderRow(
                    value: Binding(
                        get: { profile.weightKG },
                        set: {
                            profile.weightKG = $0
                            profile.updatedDate = Date()
                            refreshRecommendation()
                        }
                    ),
                    range: 40...200,
                    step: 0.5,
                    label: "Weight",
                    valueText: "\(profile.weightKG.oneDecimalString) kg",
                    color: .nutriBlue
                )

                sliderRow(
                    value: Binding(
                        get: { Double(profile.age) },
                        set: {
                            profile.age = Int($0)
                            profile.updatedDate = Date()
                            refreshRecommendation()
                        }
                    ),
                    range: 15...80,
                    step: 1,
                    label: "Age",
                    valueText: "\(profile.age) years",
                    color: .nutriBlue
                )
            }

            // MARK: - About You
            Section("About You") {
                Picker("Biological Sex", selection: $profile.biologicalSex) {
                    ForEach(BiologicalSex.allCases) { sex in
                        Text(sex.displayName).tag(sex)
                    }
                }
                .onChange(of: profile.biologicalSex) { _, _ in
                    refreshRecommendation()
                }

                Picker("Activity Level", selection: $profile.activityLevel) {
                    ForEach(ActivityLevel.allCases) { level in
                        VStack(alignment: .leading) {
                            Text(level.displayName)
                        }
                        .tag(level)
                    }
                }
                .onChange(of: profile.activityLevel) { _, _ in
                    refreshRecommendation()
                }

                Text(profile.activityLevel.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Dietary Restrictions
            Section("Dietary Restrictions") {
                let restrictions = profile.dietaryRestrictions
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(DietaryRestriction.allCases) { restriction in
                        let isSelected = restrictions.contains(restriction)
                        Button {
                            var updated = restrictions
                            if isSelected {
                                updated.removeAll { $0 == restriction }
                            } else {
                                updated.append(restriction)
                            }
                            profile.dietaryRestrictions = updated
                            profile.updatedDate = Date()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: restriction.icon)
                                    .font(.caption2)
                                Text(restriction.displayName)
                                    .font(.caption.weight(.medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                isSelected ? Color.nutriGreen.opacity(0.15) : Color(.systemGray6),
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isSelected ? Color.nutriGreen : .clear, lineWidth: 1.5)
                            )
                            .foregroundStyle(isSelected ? .nutriGreen : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // MARK: - BMI
            Section("Body Mass Index") {
                HStack {
                    Text("BMI")
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.1f", profile.bmi))
                        .font(.title3.weight(.bold))
                    Text(profile.bmiCategory)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(bmiColor, in: Capsule())
                }
            }

            // MARK: - Recommended Goals
            if let rec = recommendation {
                Section("Recommended Goals") {
                    VStack(alignment: .leading, spacing: 8) {
                        recommendedRow("Calories", value: rec.calories, unit: "kcal", color: .calorieColor)
                        recommendedRow("Protein", value: rec.proteinGrams, unit: "g", color: .proteinColor)
                        recommendedRow("Carbs", value: rec.carbsGrams, unit: "g", color: .carbsColor)
                        recommendedRow("Fat", value: rec.fatGrams, unit: "g", color: .fatColor)
                    }

                    if let goal {
                        Button {
                            TDEECalculator.applyRecommendation(rec, to: goal)
                            try? modelContext.save()
                        } label: {
                            Label("Apply to Daily Goals", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                }
            }
        }
        .navigationTitle("Body Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !didLoad else { return }
            didLoad = true
            // Load goal manually to avoid @Query re-render loops
            let descriptor = FetchDescriptor<DailyGoal>(
                predicate: #Predicate<DailyGoal> { $0.isActive == true }
            )
            goal = try? modelContext.fetch(descriptor).first
            refreshRecommendation()
        }
    }

    private func recommendedRow(_ name: String, value: Double, unit: String, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(name)
                .font(.subheadline)
            Spacer()
            Text("\(value.oneDecimalString) \(unit)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
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
