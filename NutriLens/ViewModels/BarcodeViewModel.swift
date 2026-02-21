import SwiftUI
import SwiftData

enum BarcodeState: Equatable {
    case scanning
    case loading
    case found
    case notFound
    case error(String)
}

@Observable
final class BarcodeViewModel {
    var state: BarcodeState = .scanning
    var scannedBarcode: String = ""
    var productName: String = ""
    var brandName: String = ""
    var servingSize: String = ""
    var nutrients: NutrientInfo = .zero
    var mealType: MealType = .suggestedForCurrentTime
    var showFeedbackBanner: Bool = false
    var savedMeal: Meal?

    func lookupBarcode(_ barcode: String) async {
        scannedBarcode = barcode
        state = .loading

        do {
            let result = try await OpenFoodFactsService.fetchProduct(barcode: barcode)
            productName = result.productName
            brandName = result.brandName ?? ""
            servingSize = result.servingSize
            nutrients = result.nutrients
            state = .found
        } catch OpenFoodFactsError.productNotFound {
            state = .notFound
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func saveMeal(context: ModelContext, healthKitManager: HealthKitManager? = nil) {
        let meal = Meal(
            name: productName,
            mealType: mealType,
            sourceType: .barcode
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
        try? context.save()

        savedMeal = meal
        showFeedbackBanner = true

        if let hk = healthKitManager {
            Task { await hk.syncMeal(meal) }
        }
    }

    func rateAccuracy(_ rating: Int, context: ModelContext) {
        savedMeal?.userAccuracyRating = rating
        try? context.save()
        showFeedbackBanner = false
    }

    func reset() {
        state = .scanning
        scannedBarcode = ""
        productName = ""
        brandName = ""
        servingSize = ""
        nutrients = .zero
        mealType = .suggestedForCurrentTime
        showFeedbackBanner = false
        savedMeal = nil
    }
}
