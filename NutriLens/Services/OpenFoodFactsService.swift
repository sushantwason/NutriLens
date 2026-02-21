import Foundation

enum OpenFoodFactsError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case productNotFound
    case parsingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid barcode format."
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .productNotFound: return "Product not found in database."
        case .parsingFailed: return "Could not parse product data."
        }
    }
}

enum OpenFoodFactsService {
    struct ProductResult {
        let productName: String
        let brandName: String?
        let servingSize: String
        let barcode: String
        let nutrients: NutrientInfo
        let imageURL: String?
    }

    private static let baseURL = "https://world.openfoodfacts.org/api/v2/product"

    static func fetchProduct(barcode: String) async throws -> ProductResult {
        guard let url = URL(string: "\(baseURL)/\(barcode).json") else {
            throw OpenFoodFactsError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("NutriLens iOS App", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let data: Data
        do {
            let (responseData, _) = try await URLSession.shared.data(for: request)
            data = responseData
        } catch {
            throw OpenFoodFactsError.networkError(error)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? Int, status == 1,
              let product = json["product"] as? [String: Any] else {
            throw OpenFoodFactsError.productNotFound
        }

        let productName = product["product_name"] as? String ?? "Unknown Product"
        let brandName = product["brands"] as? String
        let servingSize = product["serving_size"] as? String ?? "100g"
        let imageURL = product["image_front_url"] as? String

        let nutriments = product["nutriments"] as? [String: Any] ?? [:]

        // Prefer per-serving values, fall back to per-100g
        let calories = nutrimentValue(nutriments, key: "energy-kcal_serving") ??
                       nutrimentValue(nutriments, key: "energy-kcal_100g") ?? 0
        let protein = nutrimentValue(nutriments, key: "proteins_serving") ??
                      nutrimentValue(nutriments, key: "proteins_100g") ?? 0
        let carbs = nutrimentValue(nutriments, key: "carbohydrates_serving") ??
                    nutrimentValue(nutriments, key: "carbohydrates_100g") ?? 0
        let fat = nutrimentValue(nutriments, key: "fat_serving") ??
                  nutrimentValue(nutriments, key: "fat_100g") ?? 0
        let fiber = nutrimentValue(nutriments, key: "fiber_serving") ??
                    nutrimentValue(nutriments, key: "fiber_100g") ?? 0
        let sugar = nutrimentValue(nutriments, key: "sugars_serving") ??
                    nutrimentValue(nutriments, key: "sugars_100g") ?? 0
        let sodium = nutrimentValue(nutriments, key: "sodium_serving") ??
                     nutrimentValue(nutriments, key: "sodium_100g") ?? 0
        let saturatedFat = nutrimentValue(nutriments, key: "saturated-fat_serving") ??
                           nutrimentValue(nutriments, key: "saturated-fat_100g") ?? 0

        let nutrients = NutrientInfo(
            calories: calories,
            proteinGrams: protein,
            carbsGrams: carbs,
            fatGrams: fat,
            fiberGrams: fiber,
            sugarGrams: sugar,
            sodiumMilligrams: sodium * 1000, // API returns grams, we store mg
            saturatedFatGrams: saturatedFat
        )

        return ProductResult(
            productName: productName,
            brandName: brandName,
            servingSize: servingSize,
            barcode: barcode,
            nutrients: nutrients,
            imageURL: imageURL
        )
    }

    private static func nutrimentValue(_ nutriments: [String: Any], key: String) -> Double? {
        if let value = nutriments[key] as? Double, value > 0 {
            return value
        }
        if let value = nutriments[key] as? Int, value > 0 {
            return Double(value)
        }
        if let str = nutriments[key] as? String, let value = Double(str), value > 0 {
            return value
        }
        return nil
    }
}
