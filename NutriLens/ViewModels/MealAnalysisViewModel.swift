import SwiftUI
import SwiftData
import WidgetKit

enum AnalysisState: Equatable {
    case idle
    case analyzing
    case success
    case error(String)
}

struct EditableFoodItem: Identifiable {
    let id = UUID()
    var name: String
    var quantity: String
    var calories: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var fiberGrams: Double
    var sugarGrams: Double

    var nutrients: NutrientInfo {
        NutrientInfo(
            calories: calories,
            proteinGrams: proteinGrams,
            carbsGrams: carbsGrams,
            fatGrams: fatGrams,
            fiberGrams: fiberGrams,
            sugarGrams: sugarGrams
        )
    }

    init(from analyzed: AnalyzedFoodItem) {
        self.name = analyzed.name
        self.quantity = analyzed.quantity
        self.calories = analyzed.nutrients.calories
        self.proteinGrams = analyzed.nutrients.proteinGrams
        self.carbsGrams = analyzed.nutrients.carbsGrams
        self.fatGrams = analyzed.nutrients.fatGrams
        self.fiberGrams = analyzed.nutrients.fiberGrams
        self.sugarGrams = analyzed.nutrients.sugarGrams
    }

    init(name: String = "", quantity: String = "") {
        self.name = name
        self.quantity = quantity
        self.calories = 0
        self.proteinGrams = 0
        self.carbsGrams = 0
        self.fatGrams = 0
        self.fiberGrams = 0
        self.sugarGrams = 0
    }
}

@MainActor @Observable
final class MealAnalysisViewModel {
    var analysisState: AnalysisState = .idle
    var foodItems: [EditableFoodItem] = []
    var mealName: String = ""
    var mealType: MealType = .suggestedForCurrentTime
    var confidenceScore: Double = 0
    var capturedImage: UIImage?
    var savedMeal: Meal?
    var showFeedbackBanner: Bool = false
    var modelUsed: String?

    private let visionService = ClaudeVisionService()

    var totalNutrients: NutrientInfo {
        foodItems.reduce(NutrientInfo.zero) { $0 + $1.nutrients }
    }

    func analyzePhoto(_ image: UIImage) async {
        capturedImage = image
        analysisState = .analyzing

        do {
            let result = try await visionService.analyzeMealPhoto(image)
            mealName = result.response.mealName
            confidenceScore = result.response.confidence
            foodItems = result.response.items.map { EditableFoodItem(from: $0) }
            mealType = .suggestedForCurrentTime
            modelUsed = result.modelUsed
            analysisState = .success
            AnalyticsService.track(.scanSuccess, parameters: ["mode": "meal", "itemCount": "\(foodItems.count)"])
        } catch {
            analysisState = .error(error.localizedDescription)
            AnalyticsService.track(.scanFailed, parameters: ["mode": "meal"])
            HapticService.errorOccurred()
        }
    }

    func analyzePhotos(_ images: [UIImage]) async {
        guard !images.isEmpty else { return }
        // Use the first image as the representative thumbnail
        capturedImage = images.first
        analysisState = .analyzing

        do {
            let result = try await visionService.analyzeMealPhotos(images)
            mealName = result.response.mealName
            confidenceScore = result.response.confidence
            foodItems = result.response.items.map { EditableFoodItem(from: $0) }
            mealType = .suggestedForCurrentTime
            modelUsed = result.modelUsed
            analysisState = .success
            AnalyticsService.track(.scanSuccess, parameters: ["mode": "meal", "itemCount": "\(foodItems.count)"])
        } catch {
            analysisState = .error(error.localizedDescription)
            AnalyticsService.track(.scanFailed, parameters: ["mode": "meal"])
            HapticService.errorOccurred()
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
            sourceType: .photoAnalysis,
            photoData: photoData,
            confidenceScore: confidenceScore
        )

        for item in foodItems {
            let foodItem = FoodItem(
                name: item.name,
                quantity: item.quantity,
                nutrients: item.nutrients
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
        AnalyticsService.track(.mealSaved, parameters: ["source": "photoAnalysis", "itemCount": "\(foodItems.count)"])
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
        modelUsed = nil
    }
}
