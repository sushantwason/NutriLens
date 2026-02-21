import Foundation
import SwiftData

enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case male
    case female

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary
    case lightlyActive
    case moderatelyActive
    case veryActive
    case extraActive

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .lightlyActive: return "Lightly Active"
        case .moderatelyActive: return "Moderately Active"
        case .veryActive: return "Very Active"
        case .extraActive: return "Extra Active"
        }
    }

    var description: String {
        switch self {
        case .sedentary: return "Little or no exercise"
        case .lightlyActive: return "Light exercise 1–3 days/week"
        case .moderatelyActive: return "Moderate exercise 3–5 days/week"
        case .veryActive: return "Hard exercise 6–7 days/week"
        case .extraActive: return "Very hard exercise or physical job"
        }
    }

    /// Mifflin-St Jeor TDEE multiplier
    var tdeeMultiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightlyActive: return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive: return 1.725
        case .extraActive: return 1.9
        }
    }

    /// Protein grams per kg of body weight
    var proteinMultiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightlyActive: return 1.4
        case .moderatelyActive: return 1.6
        case .veryActive: return 1.8
        case .extraActive: return 2.0
        }
    }
}

enum DietaryRestriction: String, Codable, CaseIterable, Identifiable {
    case vegetarian
    case vegan
    case glutenFree
    case dairyFree
    case nutFree
    case shellfishFree
    case eggFree
    case soyFree
    case lowSodium
    case halal
    case kosher

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vegetarian: return "Vegetarian"
        case .vegan: return "Vegan"
        case .glutenFree: return "Gluten-Free"
        case .dairyFree: return "Dairy-Free"
        case .nutFree: return "Nut-Free"
        case .shellfishFree: return "Shellfish-Free"
        case .eggFree: return "Egg-Free"
        case .soyFree: return "Soy-Free"
        case .lowSodium: return "Low Sodium"
        case .halal: return "Halal"
        case .kosher: return "Kosher"
        }
    }

    var icon: String {
        switch self {
        case .vegetarian: return "leaf.fill"
        case .vegan: return "leaf.circle.fill"
        case .glutenFree: return "xmark.circle.fill"
        case .dairyFree: return "drop.fill"
        case .nutFree: return "exclamationmark.triangle.fill"
        case .shellfishFree: return "exclamationmark.triangle.fill"
        case .eggFree: return "xmark.circle.fill"
        case .soyFree: return "xmark.circle.fill"
        case .lowSodium: return "bolt.slash.fill"
        case .halal: return "checkmark.seal.fill"
        case .kosher: return "checkmark.seal.fill"
        }
    }
}

@Model
final class UserProfile {
    var id: UUID = UUID()
    var heightCM: Double = 170
    var weightKG: Double = 70
    var age: Int = 30
    var biologicalSex: BiologicalSex = BiologicalSex.male
    var activityLevel: ActivityLevel = ActivityLevel.moderatelyActive
    var createdDate: Date = Date()
    var updatedDate: Date = Date()
    var dietaryRestrictionsJSON: String = "[]"

    init(
        heightCM: Double = 170,
        weightKG: Double = 70,
        age: Int = 30,
        biologicalSex: BiologicalSex = .male,
        activityLevel: ActivityLevel = .moderatelyActive
    ) {
        self.id = UUID()
        self.heightCM = heightCM
        self.weightKG = weightKG
        self.age = age
        self.biologicalSex = biologicalSex
        self.activityLevel = activityLevel
        self.createdDate = Date()
        self.updatedDate = Date()
    }

    /// Dietary restrictions stored as JSON string for SwiftData compatibility
    var dietaryRestrictions: [DietaryRestriction] {
        get {
            guard let data = dietaryRestrictionsJSON.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([DietaryRestriction].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                dietaryRestrictionsJSON = json
            } else {
                dietaryRestrictionsJSON = "[]"
            }
        }
    }

    /// Body Mass Index
    var bmi: Double {
        let heightM = heightCM / 100.0
        guard heightM > 0 else { return 0 }
        return weightKG / (heightM * heightM)
    }

    /// BMI category label
    var bmiCategory: String {
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Normal"
        case 25..<30: return "Overweight"
        default: return "Obese"
        }
    }
}
