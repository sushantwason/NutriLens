import Foundation

struct NutrientInfo: Codable, Hashable {
    // MARK: - Macronutrients
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

    // MARK: - Micronutrients (vitamins)
    var vitaminAMicrograms: Double
    var vitaminCMilligrams: Double
    var vitaminDMicrograms: Double
    var vitaminEMilligrams: Double
    var vitaminKMicrograms: Double
    var vitaminB6Milligrams: Double
    var vitaminB12Micrograms: Double
    var folateMicrograms: Double

    // MARK: - Micronutrients (minerals)
    var calciumMilligrams: Double
    var ironMilligrams: Double
    var magnesiumMilligrams: Double
    var potassiumMilligrams: Double
    var zincMilligrams: Double

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
        transFatGrams: Double = 0,
        vitaminAMicrograms: Double = 0,
        vitaminCMilligrams: Double = 0,
        vitaminDMicrograms: Double = 0,
        vitaminEMilligrams: Double = 0,
        vitaminKMicrograms: Double = 0,
        vitaminB6Milligrams: Double = 0,
        vitaminB12Micrograms: Double = 0,
        folateMicrograms: Double = 0,
        calciumMilligrams: Double = 0,
        ironMilligrams: Double = 0,
        magnesiumMilligrams: Double = 0,
        potassiumMilligrams: Double = 0,
        zincMilligrams: Double = 0
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
        self.vitaminAMicrograms = vitaminAMicrograms
        self.vitaminCMilligrams = vitaminCMilligrams
        self.vitaminDMicrograms = vitaminDMicrograms
        self.vitaminEMilligrams = vitaminEMilligrams
        self.vitaminKMicrograms = vitaminKMicrograms
        self.vitaminB6Milligrams = vitaminB6Milligrams
        self.vitaminB12Micrograms = vitaminB12Micrograms
        self.folateMicrograms = folateMicrograms
        self.calciumMilligrams = calciumMilligrams
        self.ironMilligrams = ironMilligrams
        self.magnesiumMilligrams = magnesiumMilligrams
        self.potassiumMilligrams = potassiumMilligrams
        self.zincMilligrams = zincMilligrams
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
            transFatGrams: lhs.transFatGrams + rhs.transFatGrams,
            vitaminAMicrograms: lhs.vitaminAMicrograms + rhs.vitaminAMicrograms,
            vitaminCMilligrams: lhs.vitaminCMilligrams + rhs.vitaminCMilligrams,
            vitaminDMicrograms: lhs.vitaminDMicrograms + rhs.vitaminDMicrograms,
            vitaminEMilligrams: lhs.vitaminEMilligrams + rhs.vitaminEMilligrams,
            vitaminKMicrograms: lhs.vitaminKMicrograms + rhs.vitaminKMicrograms,
            vitaminB6Milligrams: lhs.vitaminB6Milligrams + rhs.vitaminB6Milligrams,
            vitaminB12Micrograms: lhs.vitaminB12Micrograms + rhs.vitaminB12Micrograms,
            folateMicrograms: lhs.folateMicrograms + rhs.folateMicrograms,
            calciumMilligrams: lhs.calciumMilligrams + rhs.calciumMilligrams,
            ironMilligrams: lhs.ironMilligrams + rhs.ironMilligrams,
            magnesiumMilligrams: lhs.magnesiumMilligrams + rhs.magnesiumMilligrams,
            potassiumMilligrams: lhs.potassiumMilligrams + rhs.potassiumMilligrams,
            zincMilligrams: lhs.zincMilligrams + rhs.zincMilligrams
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

    /// Whether any micronutrient data has been populated
    var hasMicronutrientData: Bool {
        vitaminAMicrograms > 0 || vitaminCMilligrams > 0 || vitaminDMicrograms > 0 ||
        vitaminEMilligrams > 0 || vitaminKMicrograms > 0 || vitaminB6Milligrams > 0 ||
        vitaminB12Micrograms > 0 || folateMicrograms > 0 || calciumMilligrams > 0 ||
        ironMilligrams > 0 || magnesiumMilligrams > 0 || potassiumMilligrams > 0 ||
        zincMilligrams > 0
    }

    // MARK: - Daily Recommended Values (for % DV calculations)

    static let dailyValues: [(keyPath: KeyPath<NutrientInfo, Double>, name: String, dv: Double, unit: String)] = [
        (\.vitaminAMicrograms, "Vitamin A", 900, "mcg"),
        (\.vitaminCMilligrams, "Vitamin C", 90, "mg"),
        (\.vitaminDMicrograms, "Vitamin D", 20, "mcg"),
        (\.vitaminEMilligrams, "Vitamin E", 15, "mg"),
        (\.vitaminKMicrograms, "Vitamin K", 120, "mcg"),
        (\.vitaminB6Milligrams, "Vitamin B6", 1.7, "mg"),
        (\.vitaminB12Micrograms, "Vitamin B12", 2.4, "mcg"),
        (\.folateMicrograms, "Folate", 400, "mcg"),
        (\.calciumMilligrams, "Calcium", 1300, "mg"),
        (\.ironMilligrams, "Iron", 18, "mg"),
        (\.magnesiumMilligrams, "Magnesium", 420, "mg"),
        (\.potassiumMilligrams, "Potassium", 4700, "mg"),
        (\.zincMilligrams, "Zinc", 11, "mg"),
        (\.fiberGrams, "Fiber", 28, "g"),
        (\.sodiumMilligrams, "Sodium", 2300, "mg"),
    ]
}
