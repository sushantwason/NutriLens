import Foundation

struct FoodSearchResult: Identifiable, Hashable {
    let fdcId: Int
    let description: String
    let brandName: String?
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let servingSize: String?

    var id: Int { fdcId }
}

@MainActor @Observable
final class TextFoodSearchService {

    // MARK: - Published State

    var searchResults: [FoodSearchResult] = []
    var isSearching = false
    var error: String?

    // MARK: - Private

    private let baseURL = "https://api.nal.usda.gov/fdc/v1/foods/search"
    private let apiKey = "DEMO_KEY"
    private let pageSize = 20

    /// Tracks the latest search task so previous in-flight requests can be cancelled.
    /// nonisolated(unsafe) to allow deinit cancellation from non-MainActor context.
    private nonisolated(unsafe) var currentSearchTask: Task<Void, Never>?

    nonisolated deinit {
        currentSearchTask?.cancel()
    }

    /// Monotonically increasing token used to discard stale results after debounce.
    private var searchToken: UInt64 = 0

    // MARK: - Nutrient ID Constants

    private enum NutrientID {
        static let energy      = 1008 // Energy (kcal)
        static let protein     = 1003
        static let carbs       = 1005
        static let fat         = 1004
        static let fiber       = 1079
        static let sugar       = 2000
        static let sodium      = 1093
        static let cholesterol = 1253
        static let saturatedFat = 1258
        static let transFat    = 1257
    }

    // MARK: - Search

    /// Performs a debounced search against the USDA FoodData Central API.
    /// Calling this method again within the 300 ms debounce window cancels the previous request.
    func search(query: String) async {
        // Cancel any in-flight search.
        currentSearchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            error = nil
            return
        }

        // Bump the token so stale completions are ignored.
        searchToken &+= 1
        let token = searchToken

        isSearching = true
        error = nil

        currentSearchTask = Task {
            // Debounce: wait 300 ms before firing the network request.
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
            } catch {
                // Task was cancelled during debounce — bail out silently.
                return
            }

            guard !Task.isCancelled else { return }

            await performSearch(query: trimmed, token: token)
        }
    }

    // MARK: - Conversion

    /// Converts a `FoodSearchResult` into the app-internal format.
    func toFoodItem(_ result: FoodSearchResult) -> (name: String, nutrients: NutrientInfo) {
        let name: String
        if let brand = result.brandName, !brand.isEmpty {
            name = "\(result.description) (\(brand))"
        } else {
            name = result.description
        }

        let nutrients = NutrientInfo(
            calories: result.calories,
            proteinGrams: result.protein,
            carbsGrams: result.carbs,
            fatGrams: result.fat
        )

        return (name: name, nutrients: nutrients)
    }

    // MARK: - Private Helpers

    private func performSearch(query: String, token: UInt64) async {
        guard var components = URLComponents(string: baseURL) else {
            error = "Invalid search URL."
            isSearching = false
            return
        }

        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "pageSize", value: String(pageSize))
        ]

        guard let url = components.url else {
            error = "Could not construct search URL."
            isSearching = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue("MealSight iOS App", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // If a newer search was started while this one was in-flight, discard the result.
            guard token == searchToken else { return }

            guard let httpResponse = response as? HTTPURLResponse else {
                error = "Unexpected response from server."
                isSearching = false
                return
            }

            guard httpResponse.statusCode == 200 else {
                error = "Search failed (HTTP \(httpResponse.statusCode))."
                isSearching = false
                return
            }

            let results = try parseResponse(data: data)
            searchResults = results
            isSearching = false

        } catch is CancellationError {
            // Cancelled — no-op.
        } catch {
            guard token == searchToken else { return }
            self.error = error.localizedDescription
            isSearching = false
        }
    }

    /// Parses the USDA FoodData Central JSON response into an array of `FoodSearchResult`.
    private func parseResponse(data: Data) throws -> [FoodSearchResult] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let foods = json["foods"] as? [[String: Any]] else {
            return []
        }

        return foods.compactMap { food -> FoodSearchResult? in
            guard let fdcId = food["fdcId"] as? Int,
                  let description = food["description"] as? String else {
                return nil
            }

            let brandName = food["brandName"] as? String ?? food["brandOwner"] as? String
            let servingSize = food["servingSize"] as? Double
            let servingSizeUnit = food["servingSizeUnit"] as? String
            let servingString: String?
            if let size = servingSize, let unit = servingSizeUnit {
                servingString = "\(Int(size))\(unit)"
            } else if let hh = food["householdServingFullText"] as? String, !hh.isEmpty {
                servingString = hh
            } else {
                servingString = nil
            }

            // Extract nutrients from the foodNutrients array.
            let foodNutrients = food["foodNutrients"] as? [[String: Any]] ?? []
            let nutrientMap = buildNutrientMap(from: foodNutrients)

            let calories = nutrientMap[NutrientID.energy] ?? 0
            let protein  = nutrientMap[NutrientID.protein] ?? 0
            let carbs    = nutrientMap[NutrientID.carbs] ?? 0
            let fat      = nutrientMap[NutrientID.fat] ?? 0

            return FoodSearchResult(
                fdcId: fdcId,
                description: formatDescription(description),
                brandName: brandName,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                servingSize: servingString
            )
        }
    }

    /// Builds a dictionary mapping nutrient ID to its value from the USDA foodNutrients array.
    private func buildNutrientMap(from foodNutrients: [[String: Any]]) -> [Int: Double] {
        var map: [Int: Double] = [:]
        for nutrient in foodNutrients {
            guard let nutrientId = nutrient["nutrientId"] as? Int,
                  let value = extractDouble(from: nutrient, key: "value") else {
                continue
            }
            map[nutrientId] = value
        }
        return map
    }

    /// Converts a USDA `FoodSearchResult` into a full `NutrientInfo` with all available micronutrients.
    /// This is useful when you need the complete nutrient profile, not just the macro summary.
    func toFullNutrientInfo(from foodNutrients: [[String: Any]]) -> NutrientInfo {
        let map = buildNutrientMap(from: foodNutrients)
        return NutrientInfo(
            calories: map[NutrientID.energy] ?? 0,
            proteinGrams: map[NutrientID.protein] ?? 0,
            carbsGrams: map[NutrientID.carbs] ?? 0,
            fatGrams: map[NutrientID.fat] ?? 0,
            fiberGrams: map[NutrientID.fiber] ?? 0,
            sugarGrams: map[NutrientID.sugar] ?? 0,
            sodiumMilligrams: map[NutrientID.sodium] ?? 0,
            cholesterolMilligrams: map[NutrientID.cholesterol] ?? 0,
            saturatedFatGrams: map[NutrientID.saturatedFat] ?? 0,
            transFatGrams: map[NutrientID.transFat] ?? 0
        )
    }

    /// Attempts to read a `Double` from a dictionary value that may be Double, Int, or String.
    private func extractDouble(from dict: [String: Any], key: String) -> Double? {
        if let value = dict[key] as? Double {
            return value
        }
        if let value = dict[key] as? Int {
            return Double(value)
        }
        if let str = dict[key] as? String, let value = Double(str) {
            return value
        }
        return nil
    }

    /// Cleans up USDA descriptions: title-cases all-uppercase text for readability.
    private func formatDescription(_ raw: String) -> String {
        // Many USDA entries are ALL CAPS. Convert to title case if so.
        if raw == raw.uppercased() && raw.count > 3 {
            return raw.localizedCapitalized
        }
        return raw
    }
}
