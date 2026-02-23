import Foundation

struct MealAnalysisResponse: Codable {
    let mealName: String
    let confidence: Double
    let dietaryFlags: [String]?
    let items: [AnalyzedFoodItem]
}

struct RecipeAnalysisResponse: Codable {
    let mealName: String
    let confidence: Double
    let estimatedServings: Int
    let dietaryFlags: [String]?
    let items: [AnalyzedFoodItem]
}

struct AnalyzedFoodItem: Codable {
    let name: String
    let quantity: String
    let nutrients: AnalyzedNutrients
}

struct AnalyzedNutrients: Codable {
    let calories: Double
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    let fiberGrams: Double
    let sugarGrams: Double
    // Optional micronutrients (may not always be present)
    let sodiumMilligrams: Double?
    let cholesterolMilligrams: Double?
    let saturatedFatGrams: Double?
    let transFatGrams: Double?
    let vitaminAMicrograms: Double?
    let vitaminCMilligrams: Double?
    let vitaminDMicrograms: Double?
    let vitaminEMilligrams: Double?
    let vitaminKMicrograms: Double?
    let vitaminB6Milligrams: Double?
    let vitaminB12Micrograms: Double?
    let folateMicrograms: Double?
    let calciumMilligrams: Double?
    let ironMilligrams: Double?
    let magnesiumMilligrams: Double?
    let potassiumMilligrams: Double?
    let zincMilligrams: Double?

    func toNutrientInfo() -> NutrientInfo {
        NutrientInfo(
            calories: calories,
            proteinGrams: proteinGrams,
            carbsGrams: carbsGrams,
            fatGrams: fatGrams,
            fiberGrams: fiberGrams,
            sugarGrams: sugarGrams,
            sodiumMilligrams: sodiumMilligrams ?? 0,
            cholesterolMilligrams: cholesterolMilligrams ?? 0,
            saturatedFatGrams: saturatedFatGrams ?? 0,
            transFatGrams: transFatGrams ?? 0,
            vitaminAMicrograms: vitaminAMicrograms ?? 0,
            vitaminCMilligrams: vitaminCMilligrams ?? 0,
            vitaminDMicrograms: vitaminDMicrograms ?? 0,
            vitaminEMilligrams: vitaminEMilligrams ?? 0,
            vitaminKMicrograms: vitaminKMicrograms ?? 0,
            vitaminB6Milligrams: vitaminB6Milligrams ?? 0,
            vitaminB12Micrograms: vitaminB12Micrograms ?? 0,
            folateMicrograms: folateMicrograms ?? 0,
            calciumMilligrams: calciumMilligrams ?? 0,
            ironMilligrams: ironMilligrams ?? 0,
            magnesiumMilligrams: magnesiumMilligrams ?? 0,
            potassiumMilligrams: potassiumMilligrams ?? 0,
            zincMilligrams: zincMilligrams ?? 0
        )
    }
}

struct LabelAnalysisResponse: Codable {
    let productName: String
    let brandName: String?
    let servingSize: String
    let servingsPerContainer: Double?
    let nutrients: LabelNutrients
}

struct LabelNutrients: Codable {
    let calories: Double
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    let fiberGrams: Double
    let sugarGrams: Double
    let sodiumMilligrams: Double
    let cholesterolMilligrams: Double
    let saturatedFatGrams: Double
    let transFatGrams: Double
    // Optional micronutrients from labels
    let vitaminAMicrograms: Double?
    let vitaminCMilligrams: Double?
    let vitaminDMicrograms: Double?
    let vitaminEMilligrams: Double?
    let vitaminKMicrograms: Double?
    let vitaminB6Milligrams: Double?
    let vitaminB12Micrograms: Double?
    let folateMicrograms: Double?
    let calciumMilligrams: Double?
    let ironMilligrams: Double?
    let magnesiumMilligrams: Double?
    let potassiumMilligrams: Double?
    let zincMilligrams: Double?

    func toNutrientInfo() -> NutrientInfo {
        NutrientInfo(
            calories: calories,
            proteinGrams: proteinGrams,
            carbsGrams: carbsGrams,
            fatGrams: fatGrams,
            fiberGrams: fiberGrams,
            sugarGrams: sugarGrams,
            sodiumMilligrams: sodiumMilligrams,
            cholesterolMilligrams: cholesterolMilligrams,
            saturatedFatGrams: saturatedFatGrams,
            transFatGrams: transFatGrams,
            vitaminAMicrograms: vitaminAMicrograms ?? 0,
            vitaminCMilligrams: vitaminCMilligrams ?? 0,
            vitaminDMicrograms: vitaminDMicrograms ?? 0,
            vitaminEMilligrams: vitaminEMilligrams ?? 0,
            vitaminKMicrograms: vitaminKMicrograms ?? 0,
            vitaminB6Milligrams: vitaminB6Milligrams ?? 0,
            vitaminB12Micrograms: vitaminB12Micrograms ?? 0,
            folateMicrograms: folateMicrograms ?? 0,
            calciumMilligrams: calciumMilligrams ?? 0,
            ironMilligrams: ironMilligrams ?? 0,
            magnesiumMilligrams: magnesiumMilligrams ?? 0,
            potassiumMilligrams: potassiumMilligrams ?? 0,
            zincMilligrams: zincMilligrams ?? 0
        )
    }
}
