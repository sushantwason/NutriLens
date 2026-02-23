import SwiftUI
import SwiftData

struct ExportView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<DailyGoal> { $0.isActive == true })
    private var activeGoals: [DailyGoal]

    @State private var format: ExportFormat = .csv
    @State private var range: ExportRange = .week
    @State private var shareURL: URL?
    @State private var showShareSheet = false
    @State private var allMeals: [Meal] = []
    @State private var isLoading = true
    @State private var isExporting = false

    private var filteredMeals: [Meal] {
        ExportService.filteredMeals(allMeals, range: range)
    }

    var body: some View {
        Form {
            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 20)
                }
            } else {
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
                            if isExporting {
                                ProgressView()
                            } else {
                                Label("Export \(format.rawValue)", systemImage: format == .csv ? "tablecells" : "doc.richtext")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                    }
                    .disabled(filteredMeals.isEmpty || isExporting)
                }
            }
        }
        .navigationTitle("Export Data")
        .task {
            await loadMeals()
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheetView(activityItems: [url])
            }
        }
    }

    private func loadMeals() async {
        // Yield to let the loading UI render before fetch blocks main actor
        try? await Task.sleep(nanoseconds: 50_000_000)

        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        do {
            var descriptor = FetchDescriptor<Meal>(
                predicate: #Predicate<Meal> { $0.isConfirmedByUser == true && $0.timestamp >= sixMonthsAgo },
                sortBy: [SortDescriptor(\Meal.timestamp, order: .reverse)]
            )
            descriptor.fetchLimit = 5000
            allMeals = try modelContext.fetch(descriptor)
        } catch {
            allMeals = []
        }
        isLoading = false
    }

    private func exportData() {
        isExporting = true
        let mealsToExport = filteredMeals
        let goal = activeGoals.first
        let selectedFormat = format

        Task.detached {
            let url: URL
            switch selectedFormat {
            case .csv:
                url = ExportService.generateCSV(meals: mealsToExport)
            case .pdf:
                url = ExportService.generatePDF(meals: mealsToExport, goal: goal)
            }
            await MainActor.run {
                shareURL = url
                isExporting = false
                showShareSheet = true
            }
        }
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
