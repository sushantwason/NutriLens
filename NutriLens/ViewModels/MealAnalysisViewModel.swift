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

    private let visionService = ClaudeVisionService()

    var totalNutrients: NutrientInfo {
        foodItems.reduce(NutrientInfo.zero) { $0 + $1.nutrients }
    }

    func analyzePhoto(_ image: UIImage) async {
        capturedImage = image
        analysisState = .analyzing

        do {
            let response = try await visionService.analyzeMealPhoto(image)
            mealName = response.mealName
            confidenceScore = response.confidence
            foodItems = response.items.map { EditableFoodItem(from: $0) }
            mealType = .suggestedForCurrentTime
            analysisState = .success
        } catch {
            analysisState = .error(error.localizedDescription)
            HapticService.errorOccurred()
        }
    }

    func analyzePhotos(_ images: [UIImage]) async {
        guard !images.isEmpty else { return }
        // Use the first image as the representative thumbnail
        capturedImage = images.first
        analysisState = .analyzing

        do {
            let response = try await visionService.analyzeMealPhotos(images)
            mealName = response.mealName
            confidenceScore = response.confidence
            foodItems = response.items.map { EditableFoodItem(from: $0) }
            mealType = .suggestedForCurrentTime
            analysisState = .success
        } catch {
            analysisState = .error(error.localizedDescription)
            HapticService.errorOccurred()
        }
    }

    func addEmptyItem() {
        foodItems.append(EditableFoodItem())
    }

    func removeItems(at offsets: IndexSet) {
        foodItems.remove(atOffsets: offsets)
    }

    func saveMeal(context: ModelContext, healthKitManager: HealthKitManager? = nil) {
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
        WidgetCenter.shared.reloadAllTimelines()

        // Sync to HealthKit
        if let hk = healthKitManager {
            Task { await hk.syncMeal(meal) }
        }
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
    }
}
