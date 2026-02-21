import SwiftUI
import SwiftData

struct WeightSummaryCard: View {
    @Query(sort: \WeightEntry.date, order: .reverse) private var weightEntries: [WeightEntry]
    @Query private var profiles: [UserProfile]

    private var latestWeight: WeightEntry? {
        weightEntries.first
    }

    private var profile: UserProfile? {
        profiles.first
    }

    private var bmi: Double? {
        guard let profile else { return nil }
        let heightM = profile.heightCM / 100.0
        guard heightM > 0 else { return nil }
        // Use latest weight entry if available, otherwise profile weight
        let weight = latestWeight?.weightKG ?? profile.weightKG
        return weight / (heightM * heightM)
    }

    private var bmiCategory: String? {
        guard let bmi else { return nil }
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Normal"
        case 25..<30: return "Overweight"
        default: return "Obese"
        }
    }

    private var bmiColor: Color {
        guard let bmi else { return .secondary }
        switch bmi {
        case ..<18.5: return .nutriOrange
        case 18.5..<25: return .nutriGreen
        case 25..<30: return .nutriOrange
        default: return .nutriRed
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "scalemass.fill")
                .font(.title2)
                .foregroundStyle(.nutriPurple)
                .frame(width: 44, height: 44)
                .background(.nutriPurple.opacity(0.15), in: Circle())

            if let weight = latestWeight {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(weight.weightKG.oneDecimalString) kg")
                        .font(.headline)

                    Text(weight.date.mediumDateString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let profile {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(profile.weightKG.oneDecimalString) kg")
                        .font(.headline)

                    Text("From profile")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let bmi, let category = bmiCategory {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("BMI \(bmi, specifier: "%.1f")")
                        .font(.subheadline.weight(.semibold))

                    Text(category)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(bmiColor, in: Capsule())
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
