import SwiftUI
import SwiftData
import WidgetKit

struct WaterProgressCard: View {
    @Query(sort: \WaterEntry.timestamp, order: .reverse) private var allWaterEntries: [WaterEntry]
    @Query(filter: #Predicate<DailyGoal> { $0.isActive == true }) private var activeGoals: [DailyGoal]
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthKitManager.self) private var healthKitManager

    @State private var showCustomSheet = false
    @State private var customAmount: Double = 350

    private var todaysWaterML: Double {
        let start = Date().startOfDay
        let end = Date().endOfDay
        return allWaterEntries
            .filter { $0.timestamp >= start && $0.timestamp < end }
            .reduce(0) { $0 + $1.milliliters }
    }

    private var waterTarget: Double {
        activeGoals.first?.waterTargetML ?? 2000
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                MacroRingView(
                    progress: todaysWaterML.progressRatio(of: waterTarget),
                    color: .waterColor,
                    lineWidth: 10,
                    size: 80
                ) {
                    VStack(spacing: 1) {
                        Image(systemName: "drop.fill")
                            .font(.caption)
                            .foregroundStyle(.waterColor)
                        Text(todaysWaterML.mlString)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Water Today")
                        .font(.headline)

                    Text("\(todaysWaterML.mlString) / \(waterTarget.mlString) ml")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if todaysWaterML >= waterTarget {
                        Label("Goal reached!", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.nutriGreen)
                    }
                }

                Spacer()
            }

            // Quick-add buttons
            HStack(spacing: 8) {
                quickAddButton(ml: 250, icon: "cup.and.saucer.fill", label: "250 ml")
                quickAddButton(ml: 500, icon: "waterbottle.fill", label: "500 ml")

                Button {
                    showCustomSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.caption2.weight(.bold))
                        Text("Custom")
                            .font(.caption2.weight(.medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.waterColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.waterColor)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showCustomSheet) {
            customWaterSheet
        }
    }

    private func quickAddButton(ml: Double, icon: String, label: String) -> some View {
        Button {
            addWater(ml: ml)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption2.weight(.medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.waterColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.waterColor)
        }
    }

    private var customWaterSheet: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    HStack {
                        TextField("ml", value: $customAmount, format: .number)
                            .keyboardType(.numberPad)
                            .font(.title2.weight(.bold))
                        Text("ml")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Add Water") {
                        addWater(ml: customAmount)
                        showCustomSheet = false
                    }
                    .frame(maxWidth: .infinity)
                    .font(.headline)
                }
            }
            .navigationTitle("Custom Amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCustomSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func addWater(ml: Double) {
        guard ml > 0 else { return }
        HapticService.waterAdded()
        let entry = WaterEntry(milliliters: ml)
        modelContext.insert(entry)
        try? modelContext.save()
        WidgetCenter.shared.reloadAllTimelines()

        // Sync to HealthKit
        Task { await healthKitManager.syncWater(milliliters: ml, date: entry.timestamp) }
    }
}
