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

    func toNutrientInfo() -> NutrientInfo {
        NutrientInfo(
            calories: calories,
            proteinGrams: proteinGrams,
            carbsGrams: carbsGrams,
            fatGrams: fatGrams,
            fiberGrams: fiberGrams,
            sugarGrams: sugarGrams
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
            transFatGrams: transFatGrams
        )
    }
}
