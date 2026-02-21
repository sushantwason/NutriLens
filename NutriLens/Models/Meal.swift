import Foundation
import SwiftData

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.fill"
        case .snack: return "cup.and.saucer.fill"
        }
    }

    /// Suggest a meal type based on the current time of day
    static var suggestedForCurrentTime: MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<10:  return .breakfast
        case 10..<14: return .lunch
        case 14..<17: return .snack
        default:      return .dinner
        }
    }
}

enum MealSourceType: String, Codable {
    case photoAnalysis
    case nutritionLabel
    case manual
    case barcode
    case recipe
}

@Model
final class Meal {
    var id: UUID = UUID()
    var name: String = ""
    var mealType: MealType = MealType.lunch
    var sourceType: MealSourceType = MealSourceType.photoAnalysis
    var timestamp: Date = Date()
    var notes: String?

    @Attribute(.externalStorage)
    var photoData: Data?

    @Relationship(deleteRule: .cascade, inverse: \FoodItem.meal)
    var foodItems: [FoodItem] = []

    // Denormalized totals for fast querying
    var totalCalories: Double = 0
    var totalProteinGrams: Double = 0
    var totalCarbsGrams: Double = 0
    var totalFatGrams: Double = 0
    var totalFiberGrams: Double = 0
    var totalSugarGrams: Double = 0

    var confidenceScore: Double?
    var isConfirmedByUser: Bool = false
    var isFavorite: Bool = false
    var userAccuracyRating: Int?

    init(
        name: String,
        mealType: MealType,
        sourceType: MealSourceType,
        timestamp: Date = Date(),
        photoData: Data? = nil,
        confidenceScore: Double? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.mealType = mealType
        self.sourceType = sourceType
        self.timestamp = timestamp
        self.photoData = photoData
        self.confidenceScore = confidenceScore
    }

    func recalculateTotals() {
        let totals = foodItems.reduce(NutrientInfo.zero) { $0 + $1.nutrients }
        totalCalories = totals.calories
        totalProteinGrams = totals.proteinGrams
        totalCarbsGrams = totals.carbsGrams
        totalFatGrams = totals.fatGrams
        totalFiberGrams = totals.fiberGrams
        totalSugarGrams = totals.sugarGrams
    }

    /// Creates a new Meal with the same food items but current timestamp for quick re-logging
    func relogCopy() -> Meal {
        let copy = Meal(
            name: name,
            mealType: MealType.suggestedForCurrentTime,
            sourceType: sourceType,
            photoData: photoData,
            confidenceScore: confidenceScore
        )
        for item in foodItems {
            let newItem = FoodItem(
                name: item.name,
                quantity: item.quantity,
                nutrients: item.nutrients
            )
            copy.foodItems.append(newItem)
        }
        copy.recalculateTotals()
        copy.isConfirmedByUser = true
        return copy
    }
}
