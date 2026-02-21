import Foundation
import SwiftData

@Model
final class NutritionLabel {
    var id: UUID = UUID()
    var productName: String = ""
    var brandName: String?
    var servingSize: String = ""
    var servingsPerContainer: Double?
    var nutrients: NutrientInfo = NutrientInfo()
    var scannedDate: Date = Date()
    var barcode: String?

    @Attribute(.externalStorage)
    var labelPhotoData: Data?

    init(
        productName: String,
        brandName: String? = nil,
        servingSize: String,
        servingsPerContainer: Double? = nil,
        nutrients: NutrientInfo,
        labelPhotoData: Data? = nil
    ) {
        self.id = UUID()
        self.productName = productName
        self.brandName = brandName
        self.servingSize = servingSize
        self.servingsPerContainer = servingsPerContainer
        self.nutrients = nutrients
        self.scannedDate = Date()
        self.labelPhotoData = labelPhotoData
    }
}
