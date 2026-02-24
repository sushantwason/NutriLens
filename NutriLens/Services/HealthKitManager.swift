import Foundation
import HealthKit

@MainActor @Observable
final class HealthKitManager {
    private(set) var isAuthorized = false
    private(set) var isAvailable = false
    private var healthStore: HKHealthStore?

    init() {
        isAvailable = HKHealthStore.isHealthDataAvailable()
        if isAvailable {
            healthStore = HKHealthStore()
        }
    }

    // MARK: - Types

    private var typesToRead: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        if let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMass)
        }
        return types
    }

    private var typesToWrite: Set<HKSampleType> {
        let identifiers: [HKQuantityTypeIdentifier] = [
            .dietaryEnergyConsumed,
            .dietaryProtein,
            .dietaryCarbohydrates,
            .dietaryFatTotal,
            .dietaryWater
        ]
        return Set(identifiers.compactMap { HKObjectType.quantityType(forIdentifier: $0) })
    }

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        guard isAvailable, let store = healthStore else { return false }
        do {
            try await store.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            isAuthorized = true
            return true
        } catch {
            isAuthorized = false
            return false
        }
    }

    // MARK: - Write: Dietary data from a Meal

    func syncMeal(_ meal: Meal) async {
        guard isAuthorized, let store = healthStore else { return }
        let date = meal.timestamp

        await writeSample(.dietaryEnergyConsumed, value: meal.totalCalories, unit: .kilocalorie(), date: date, store: store)
        await writeSample(.dietaryProtein, value: meal.totalProteinGrams, unit: .gram(), date: date, store: store)
        await writeSample(.dietaryCarbohydrates, value: meal.totalCarbsGrams, unit: .gram(), date: date, store: store)
        await writeSample(.dietaryFatTotal, value: meal.totalFatGrams, unit: .gram(), date: date, store: store)
    }

    // MARK: - Write: Water

    func syncWater(milliliters: Double, date: Date) async {
        guard isAuthorized, let store = healthStore else { return }
        await writeSample(.dietaryWater, value: milliliters, unit: .literUnit(with: .milli), date: date, store: store)
    }

    // MARK: - Read: Latest weight

    func fetchLatestWeight() async -> Double? {
        guard isAuthorized, let store = healthStore,
              let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return nil }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        // Use a single continuation with a timeout via stopping the query
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, _ in
                guard !hasResumed else { return }
                hasResumed = true
                let weight = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: weight)
            }
            store.execute(query)

            // Timeout: stop the query after 10 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
                guard !hasResumed else { return }
                hasResumed = true
                store.stop(query)
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - Private

    private func writeSample(
        _ identifier: HKQuantityTypeIdentifier,
        value: Double,
        unit: HKUnit,
        date: Date,
        store: HKHealthStore
    ) async {
        guard value > 0,
              let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return }

        let quantity = HKQuantity(unit: unit, doubleValue: value)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)

        do {
            try await store.save(sample)
        } catch {
            print("HealthKit write failed for \(identifier.rawValue): \(error.localizedDescription)")
        }
    }
}
