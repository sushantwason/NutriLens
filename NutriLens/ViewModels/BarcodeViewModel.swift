import SwiftUI
import SwiftData
import UIKit
import WidgetKit

enum BarcodeState: Equatable {
    case scanning
    case loading
    case found
    case notFound
    case error(String)
}

@MainActor @Observable
final class BarcodeViewModel {
    var state: BarcodeState = .scanning
    var scannedBarcode: String = ""
    var productName: String = ""
    var brandName: String = ""
    var servingSize: String = ""
    var nutrients: NutrientInfo = .zero
    var imageURL: String?
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
            imageURL = result.imageURL
            state = .found
        } catch OpenFoodFactsError.productNotFound {
            state = .notFound
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func saveMeal(context: ModelContext) {
        let meal = Meal(
            name: productName,
            mealType: mealType,
            sourceType: .barcode,
            photoData: downloadedImageData
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
            savedMeal = meal
            showFeedbackBanner = true
        } catch {
            state = .error("Failed to save meal: \(error.localizedDescription)")
            return
        }

        WidgetCenter.shared.reloadAllTimelines()

    }

    /// Downloads and compresses the product image for storage.
    /// Called when the barcode result is displayed so the image is ready when the user saves.
    func downloadProductImage() async {
        guard let urlString = imageURL,
              let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let uiImage = UIImage(data: data) else { return }
            downloadedImageData = ImageProcessor.compressForStorage(uiImage)
        } catch {
            // Image download failed — not critical, meal saves without photo
        }
    }

    private(set) var downloadedImageData: Data?

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
        state = .scanning
        scannedBarcode = ""
        productName = ""
        brandName = ""
        servingSize = ""
        nutrients = .zero
        imageURL = nil
        downloadedImageData = nil
        mealType = .suggestedForCurrentTime
        showFeedbackBanner = false
        savedMeal = nil
    }
}
