import SwiftUI
import SwiftData

struct BarcodeResultView: View {
    @Bindable var viewModel: BarcodeViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthKitManager.self) private var healthKitManager

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .scanning:
                    scanningView
                case .loading:
                    loadingView
                case .found:
                    productView
                case .notFound:
                    notFoundView
                case .error(let message):
                    errorView(message)
                }
            }
            .navigationTitle("Barcode Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.showFeedbackBanner ? "Done" : "Cancel") {
                        dismiss()
                    }
                }
                if viewModel.state == .found && !viewModel.showFeedbackBanner {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            viewModel.saveMeal(context: modelContext, healthKitManager: healthKitManager)
                        }
                        .bold()
                    }
                }
            }
        }
    }

    // MARK: - Scanning

    private var scanningView: some View {
        VStack(spacing: 20) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Point camera at a barcode...")
                .font(.headline)
                .foregroundStyle(.secondary)

            ProgressView()
        }
        .padding()
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView("Looking up product...")
                .font(.headline)

            Text("Barcode: \(viewModel.scannedBarcode)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Product Found

    private var productView: some View {
        List {
            if let urlString = viewModel.imageURL, let url = URL(string: urlString) {
                Section {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 180)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .failure:
                            EmptyView()
                        default:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .onAppear {
                    Task { await viewModel.downloadProductImage() }
                }
            }

            Section("Product Info") {
                TextField("Product Name", text: $viewModel.productName)

                if !viewModel.brandName.isEmpty {
                    LabeledContent("Brand", value: viewModel.brandName)
                }

                LabeledContent("Serving Size", value: viewModel.servingSize)

                Picker("Meal Type", selection: $viewModel.mealType) {
                    ForEach(MealType.allCases) { type in
                        Label(type.displayName, systemImage: type.icon).tag(type)
                    }
                }

                LabeledContent("Barcode", value: viewModel.scannedBarcode)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Nutrients") {
                nutrientRow("Calories", viewModel.nutrients.calories.calorieString, "kcal", .calorieColor)
                nutrientRow("Protein", viewModel.nutrients.proteinGrams.oneDecimalString, "g", .proteinColor)
                nutrientRow("Carbs", viewModel.nutrients.carbsGrams.oneDecimalString, "g", .carbsColor)
                nutrientRow("Fat", viewModel.nutrients.fatGrams.oneDecimalString, "g", .fatColor)
                nutrientRow("Fiber", viewModel.nutrients.fiberGrams.oneDecimalString, "g", .secondary)
                nutrientRow("Sugar", viewModel.nutrients.sugarGrams.oneDecimalString, "g", .secondary)
            }

            if viewModel.showFeedbackBanner {
                Section {
                    AccuracyFeedbackBanner { rating in
                        viewModel.rateAccuracy(rating, context: modelContext)
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            guard !Task.isCancelled else { return }
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Not Found

    private var notFoundView: some View {
        ContentUnavailableView {
            Label("Product Not Found", systemImage: "barcode")
        } description: {
            Text("Barcode \(viewModel.scannedBarcode) was not found in the Open Food Facts database.")
        } actions: {
            Button("Scan Again") {
                viewModel.reset()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Lookup Failed", systemImage: "exclamationmark.triangle.fill")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await viewModel.lookupBarcode(viewModel.scannedBarcode) }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Helpers

    private func nutrientRow(_ name: String, _ value: String, _ unit: String, _ color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(name)
            Spacer()
            Text("\(value) \(unit)")
                .fontWeight(.medium)
        }
    }
}
