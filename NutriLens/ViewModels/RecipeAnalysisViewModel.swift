import SwiftUI
import SwiftData
import WidgetKit

@MainActor @Observable
final class RecipeAnalysisViewModel {
    var analysisState: AnalysisState = .idle
    var foodItems: [EditableFoodItem] = []
    var mealName: String = ""
    var mealType: MealType = .suggestedForCurrentTime
    var confidenceScore: Double = 0
    var capturedImage: UIImage?
    var savedMeal: Meal?
    var showFeedbackBanner: Bool = false
    var estimatedServings: Int = 1
    var modelUsed: String?

    private let visionService = ClaudeVisionService()

    var totalNutrients: NutrientInfo {
        foodItems.reduce(NutrientInfo.zero) { $0 + $1.nutrients }
    }

    var perServingNutrients: NutrientInfo {
        guard estimatedServings > 0 else { return totalNutrients }
        let divisor = Double(estimatedServings)
        return NutrientInfo(
            calories: totalNutrients.calories / divisor,
            proteinGrams: totalNutrients.proteinGrams / divisor,
            carbsGrams: totalNutrients.carbsGrams / divisor,
            fatGrams: totalNutrients.fatGrams / divisor,
            fiberGrams: totalNutrients.fiberGrams / divisor,
            sugarGrams: totalNutrients.sugarGrams / divisor
        )
    }

    func analyzeRecipe(_ image: UIImage) async {
        capturedImage = image
        analysisState = .analyzing

        do {
            let result = try await visionService.analyzeRecipe(image)
            mealName = result.response.mealName
            confidenceScore = result.response.confidence
            estimatedServings = max(1, result.response.estimatedServings)
            foodItems = result.response.items.map { EditableFoodItem(from: $0) }
            mealType = .suggestedForCurrentTime
            modelUsed = result.modelUsed
            analysisState = .success
            AnalyticsService.track(.scanSuccess, parameters: ["mode": "recipe", "servings": "\(estimatedServings)"])
        } catch {
            analysisState = .error(error.localizedDescription)
            AnalyticsService.track(.scanFailed, parameters: ["mode": "recipe"])
        }
    }

    func addEmptyItem() {
        foodItems.append(EditableFoodItem())
    }

    func removeItems(at offsets: IndexSet) {
        foodItems.remove(atOffsets: offsets)
    }

    func saveMeal(context: ModelContext) {
        let photoData = capturedImage.flatMap { ImageProcessor.compressForStorage($0) }

        let meal = Meal(
            name: mealName,
            mealType: mealType,
            sourceType: .recipe,
            photoData: photoData,
            confidenceScore: confidenceScore
        )

        // Save per-serving nutrients as food items
        let servings = max(1, Double(estimatedServings))
        for item in foodItems {
            let perServing = NutrientInfo(
                calories: item.calories / servings,
                proteinGrams: item.proteinGrams / servings,
                carbsGrams: item.carbsGrams / servings,
                fatGrams: item.fatGrams / servings,
                fiberGrams: item.fiberGrams / servings,
                sugarGrams: item.sugarGrams / servings
            )
            let foodItem = FoodItem(
                name: item.name,
                quantity: "\(item.quantity) (1/\(estimatedServings) recipe)",
                nutrients: perServing
            )
            meal.foodItems.append(foodItem)
        }

        meal.recalculateTotals()
        meal.isConfirmedByUser = true
        context.insert(meal)

        do {
            try context.save()
            savedMeal = meal
            showFeedbackBanner = true
        } catch {
            analysisState = .error("Failed to save meal: \(error.localizedDescription)")
            return
        }

        // Release full-resolution image after storage compression
        capturedImage = nil
        HapticService.mealSaved()
        AnalyticsService.track(.mealSaved, parameters: ["source": "recipe", "servings": "\(estimatedServings)"])
        WidgetCenter.shared.reloadAllTimelines()

    }

    func rateAccuracy(_ rating: Int, context: ModelContext) {
        savedMeal?.userAccuracyRating = rating
        do {
            try context.save()
        } catch {
            print("Failed to save accuracy rating: \(error.localizedDescription)")
        }
        showFeedbackBanner = false
    }

    func reset() {
        analysisState = .idle
        foodItems = []
        mealName = ""
        mealType = .suggestedForCurrentTime
        confidenceScore = 0
        capturedImage = nil
        savedMeal = nil
        showFeedbackBanner = false
        estimatedServings = 1
        modelUsed = nil
    }
}
