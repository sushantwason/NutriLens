import Foundation
import SwiftData

@Model
final class DailyGoal {
    var id: UUID = UUID()
    var calorieTarget: Double = 2000
    var proteinGramsTarget: Double = 150
    var carbsGramsTarget: Double = 250
    var fatGramsTarget: Double = 65
    var sugarGramsTarget: Double = 50
    var waterTargetML: Double = 2000
    var isActive: Bool = true
    var createdDate: Date = Date()

    init(
        calorieTarget: Double = 2000,
        proteinGramsTarget: Double = 150,
        carbsGramsTarget: Double = 250,
        fatGramsTarget: Double = 65,
        sugarGramsTarget: Double = 50,
        waterTargetML: Double = 2000
    ) {
        self.id = UUID()
        self.calorieTarget = calorieTarget
        self.proteinGramsTarget = proteinGramsTarget
        self.carbsGramsTarget = carbsGramsTarget
        self.fatGramsTarget = fatGramsTarget
        self.sugarGramsTarget = sugarGramsTarget
        self.waterTargetML = waterTargetML
        self.isActive = true
        self.createdDate = Date()
    }
}
