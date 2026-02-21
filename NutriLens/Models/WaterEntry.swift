import Foundation
import SwiftData

@Model
final class WaterEntry {
    var id: UUID = UUID()
    var milliliters: Double = 250
    var timestamp: Date = Date()

    init(milliliters: Double, timestamp: Date = Date()) {
        self.id = UUID()
        self.milliliters = milliliters
        self.timestamp = timestamp
    }
}
