import Foundation

struct NutrientInfo: Codable, Hashable {
    var calories: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var fiberGrams: Double
    var sugarGrams: Double
    var sodiumMilligrams: Double
    var cholesterolMilligrams: Double
    var saturatedFatGrams: Double
    var transFatGrams: Double

    init(
        calories: Double = 0,
        proteinGrams: Double = 0,
        carbsGrams: Double = 0,
        fatGrams: Double = 0,
        fiberGrams: Double = 0,
        sugarGrams: Double = 0,
        sodiumMilligrams: Double = 0,
        cholesterolMilligrams: Double = 0,
        saturatedFatGrams: Double = 0,
        transFatGrams: Double = 0
    ) {
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sugarGrams = sugarGrams
        self.sodiumMilligrams = sodiumMilligrams
        self.cholesterolMilligrams = cholesterolMilligrams
        self.saturatedFatGrams = saturatedFatGrams
        self.transFatGrams = transFatGrams
    }

    static let zero = NutrientInfo()

    static func + (lhs: NutrientInfo, rhs: NutrientInfo) -> NutrientInfo {
        NutrientInfo(
            calories: lhs.calories + rhs.calories,
            proteinGrams: lhs.proteinGrams + rhs.proteinGrams,
            carbsGrams: lhs.carbsGrams + rhs.carbsGrams,
            fatGrams: lhs.fatGrams + rhs.fatGrams,
            fiberGrams: lhs.fiberGrams + rhs.fiberGrams,
            sugarGrams: lhs.sugarGrams + rhs.sugarGrams,
            sodiumMilligrams: lhs.sodiumMilligrams + rhs.sodiumMilligrams,
            cholesterolMilligrams: lhs.cholesterolMilligrams + rhs.cholesterolMilligrams,
            saturatedFatGrams: lhs.saturatedFatGrams + rhs.saturatedFatGrams,
            transFatGrams: lhs.transFatGrams + rhs.transFatGrams
        )
    }

    /// Recalculate calories from macros: protein*4 + carbs*4 + fat*9
    var calculatedCalories: Double {
        (proteinGrams * 4) + (carbsGrams * 4) + (fatGrams * 9)
    }

    /// Check if stated calories are within tolerance of macro-derived calories
    func caloriesAreConsistent(tolerance: Double = 0.15) -> Bool {
        guard calculatedCalories > 0 else { return calories == 0 }
        let ratio = abs(calories - calculatedCalories) / calculatedCalories
        return ratio <= tolerance
    }
}
