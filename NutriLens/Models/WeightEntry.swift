import Foundation
import SwiftData

enum WeightSource: String, Codable {
    case manual
    case healthkit
}

@Model
final class WeightEntry {
    var id: UUID = UUID()
    var weightKG: Double = 0
    var date: Date = Date()
    var source: WeightSource = WeightSource.manual

    init(weightKG: Double, date: Date = Date(), source: WeightSource = .manual) {
        self.id = UUID()
        self.weightKG = weightKG
        self.date = date
        self.source = source
    }
}
