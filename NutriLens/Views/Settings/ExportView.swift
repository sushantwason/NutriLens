import SwiftUI
import SwiftData

struct ExportView: View {
    @Query(filter: #Predicate<Meal> { $0.isConfirmedByUser == true },
           sort: \Meal.timestamp, order: .reverse)
    private var allMeals: [Meal]

    @Query(filter: #Predicate<DailyGoal> { $0.isActive == true })
    private var activeGoals: [DailyGoal]

    @State private var format: ExportFormat = .csv
    @State private var range: ExportRange = .week
    @State private var shareURL: URL?
    @State private var showShareSheet = false

    private var filteredMeals: [Meal] {
        ExportService.filteredMeals(allMeals, range: range)
    }

    var body: some View {
        Form {
            Section("Format") {
                Picker("Format", selection: $format) {
                    ForEach(ExportFormat.allCases) { fmt in
                        Text(fmt.rawValue).tag(fmt)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Date Range") {
                Picker("Range", selection: $range) {
                    ForEach(ExportRange.allCases) { r in
                        Text(r.rawValue).tag(r)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                HStack {
                    Label("Meals", systemImage: "fork.knife")
                    Spacer()
                    Text("\(filteredMeals.count)")
                        .foregroundStyle(.secondary)
                }

                if !filteredMeals.isEmpty, let first = filteredMeals.last?.timestamp, let last = filteredMeals.first?.timestamp {
                    HStack {
                        Label("Period", systemImage: "calendar")
                        Spacer()
                        Text("\(first.mediumDateString) – \(last.mediumDateString)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button {
                    exportData()
                } label: {
                    HStack {
                        Spacer()
                        Label("Export \(format.rawValue)", systemImage: format == .csv ? "tablecells" : "doc.richtext")
                            .font(.headline)
                        Spacer()
                    }
                }
                .disabled(filteredMeals.isEmpty)
            }
        }
        .navigationTitle("Export Data")
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheetView(activityItems: [url])
            }
        }
    }

    private func exportData() {
        let url: URL
        switch format {
        case .csv:
            url = ExportService.generateCSV(meals: filteredMeals)
        case .pdf:
            url = ExportService.generatePDF(meals: filteredMeals, goal: activeGoals.first)
        }
        shareURL = url
        showShareSheet = true
    }
}

// MARK: - Share Sheet

struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
