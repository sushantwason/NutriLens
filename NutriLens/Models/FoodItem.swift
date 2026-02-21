import Foundation
import SwiftData

@Model
final class FoodItem {
    var id: UUID = UUID()
    var name: String = ""
    var quantity: String?
    var nutrients: NutrientInfo = NutrientInfo()
    var isUserEdited: Bool = false

    var meal: Meal?

    init(
        name: String,
        quantity: String? = nil,
        nutrients: NutrientInfo = NutrientInfo()
    ) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.nutrients = nutrients
    }
}
