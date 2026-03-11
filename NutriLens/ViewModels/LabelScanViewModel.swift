import SwiftUI
import SwiftData
import WidgetKit

@MainActor @Observable
final class LabelScanViewModel {
    var analysisState: AnalysisState = .idle
    var productName: String = ""
    var brandName: String = ""
    var servingSize: String = ""
    var servingsPerContainer: Double = 1
    var nutrients: NutrientInfo = .zero
    var capturedImage: UIImage?

    private let visionService = ClaudeVisionService()

    func analyzeLabel(_ image: UIImage) async {
        capturedImage = image
        analysisState = .analyzing

        do {
            let response = try await visionService.analyzeNutritionLabel(image)
            productName = response.productName
            brandName = response.brandName ?? ""
            servingSize = response.servingSize
            servingsPerContainer = response.servingsPerContainer ?? 1
            nutrients = response.nutrients.toNutrientInfo()
            analysisState = .success
            AnalyticsService.track(.scanSuccess, parameters: ["mode": "label"])
        } catch {
            analysisState = .error(error.localizedDescription)
            AnalyticsService.track(.scanFailed, parameters: ["mode": "label"])
        }
    }

    func saveAsLabel(context: ModelContext) {
        let photoData = capturedImage.flatMap { ImageProcessor.compressForStorage($0) }

        let label = NutritionLabel(
            productName: productName,
            brandName: brandName.isEmpty ? nil : brandName,
            servingSize: servingSize,
            servingsPerContainer: servingsPerContainer,
            nutrients: nutrients,
            labelPhotoData: photoData
        )

        context.insert(label)
        do {
            try context.save()
        } catch {
            analysisState = .error("Failed to save label: \(error.localizedDescription)")
        }
    }

    func saveAsMeal(context: ModelContext, mealType: MealType) {
        let photoData = capturedImage.flatMap { ImageProcessor.compressForStorage($0) }

        let meal = Meal(
            name: productName,
            mealType: mealType,
            sourceType: .nutritionLabel,
            photoData: photoData
        )

        let foodItem = FoodItem(
            name: productName,
            quantity: servingSize,
            nutrients: nutrients
        )
        meal.foodItems.append(foodItem)
        meal.recalculateTotals()
        meal.isConfirmedByUser = true

        context.insert(meal)
        do {
            try context.save()
        } catch {
            analysisState = .error("Failed to save meal: \(error.localizedDescription)")
        }

        // Release full-resolution image
        capturedImage = nil
        AnalyticsService.track(.mealSaved, parameters: ["source": "nutritionLabel"])
        WidgetCenter.shared.reloadAllTimelines()
    }

    func reset() {
        analysisState = .idle
        productName = ""
        brandName = ""
        servingSize = ""
        servingsPerContainer = 1
        nutrients = .zero
        capturedImage = nil
    }
}
