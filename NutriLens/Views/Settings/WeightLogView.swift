import SwiftUI
import SwiftData
import Charts

struct WeightLogView: View {
    @Query(sort: \WeightEntry.date) private var weightEntries: [WeightEntry]
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext

    @State private var newWeight: Double = 70
    @State private var showAddConfirmation = false

    private var profile: UserProfile? { profiles.first }

    private var recentEntries: [WeightEntry] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return weightEntries.filter { $0.date >= cutoff }
    }

    var body: some View {
        List {
            // MARK: - Weight Trend Chart
            if !recentEntries.isEmpty {
                Section("Weight Trend (30 days)") {
                    Chart(recentEntries) { entry in
                        LineMark(
                            x: .value("Date", entry.date, unit: .day),
                            y: .value("Weight", entry.weightKG)
                        )
                        .foregroundStyle(.nutriPurple)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", entry.date, unit: .day),
                            y: .value("Weight", entry.weightKG)
                        )
                        .foregroundStyle(.nutriPurple)
                        .symbolSize(30)
                    }
                    .frame(height: 200)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let kg = value.as(Double.self) {
                                    Text("\(kg, specifier: "%.0f") kg")
                                        .font(.caption2)
                                }
                            }
                            AxisGridLine()
                        }
                    }
                }
            }

            // MARK: - Log Weight
            Section("Log Weight") {
                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("kg", value: $newWeight, format: .number.precision(.fractionLength(1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("kg")
                        .foregroundStyle(.secondary)
                }

                Button {
                    logWeight()
                } label: {
                    Label("Save Weight Entry", systemImage: "plus.circle.fill")
                }
            }

            // MARK: - History
            if !weightEntries.isEmpty {
                Section("History") {
                    ForEach(Array(weightEntries.suffix(20).reversed())) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(entry.weightKG.oneDecimalString) kg")
                                    .font(.subheadline.weight(.medium))
                                Text(entry.date.mediumDateString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("Weight Log")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Weight Logged", isPresented: $showAddConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your weight entry has been saved.")
        }
    }

    private func logWeight() {
        guard newWeight > 0 else { return }
        let entry = WeightEntry(weightKG: newWeight)
        modelContext.insert(entry)

        // Update profile weight if exists
        if let profile {
            profile.weightKG = newWeight
            profile.updatedDate = Date()
        }

        try? modelContext.save()
        showAddConfirmation = true
    }
}
