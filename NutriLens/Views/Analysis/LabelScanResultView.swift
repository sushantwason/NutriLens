import SwiftUI
import SwiftData

struct LabelScanResultView: View {
    @Bindable var viewModel: LabelScanViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var mealType: MealType = .suggestedForCurrentTime
    @State private var saveMode: SaveMode = .asMeal

    enum SaveMode: String, CaseIterable {
        case asMeal = "Log as Meal"
        case asLabel = "Save Label"
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.analysisState {
                case .idle:
                    ContentUnavailableView("No Photo", systemImage: "photo")
                case .analyzing:
                    analyzingView
                case .success:
                    resultView
                case .error(let message):
                    errorView(message)
                }
            }
            .navigationTitle("Label Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if viewModel.analysisState == .success {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            save()
                            dismiss()
                        }
                        .bold()
                    }
                }
            }
        }
    }

    private var analyzingView: some View {
        VStack(spacing: 20) {
            if let image = viewModel.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            ProgressView("Reading nutrition label...")
                .font(.headline)
        }
        .padding()
    }

    private var resultView: some View {
        List {
            if let image = viewModel.capturedImage {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .listRowInsets(EdgeInsets())
                        .frame(maxWidth: .infinity)
                }
            }

            Section("Product Info") {
                TextField("Product Name", text: $viewModel.productName)
                TextField("Brand Name", text: $viewModel.brandName)
                TextField("Serving Size", text: $viewModel.servingSize)
                HStack {
                    Text("Servings Per Container")
                    Spacer()
                    TextField("1", value: $viewModel.servingsPerContainer, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        .onChange(of: viewModel.servingsPerContainer) { _, newValue in
                            if newValue < 0.1 { viewModel.servingsPerContainer = 1 }
                        }
                }
            }

            Section("Nutrition Facts (per serving)") {
                editableNutrientRow("Calories", value: $viewModel.nutrients.calories, unit: "kcal")
                editableNutrientRow("Protein", value: $viewModel.nutrients.proteinGrams, unit: "g")
                editableNutrientRow("Carbs", value: $viewModel.nutrients.carbsGrams, unit: "g")
                editableNutrientRow("Fat", value: $viewModel.nutrients.fatGrams, unit: "g")
                editableNutrientRow("Fiber", value: $viewModel.nutrients.fiberGrams, unit: "g")
                editableNutrientRow("Sugar", value: $viewModel.nutrients.sugarGrams, unit: "g")
                editableNutrientRow("Sodium", value: $viewModel.nutrients.sodiumMilligrams, unit: "mg")
                editableNutrientRow("Cholesterol", value: $viewModel.nutrients.cholesterolMilligrams, unit: "mg")
                editableNutrientRow("Saturated Fat", value: $viewModel.nutrients.saturatedFatGrams, unit: "g")
                editableNutrientRow("Trans Fat", value: $viewModel.nutrients.transFatGrams, unit: "g")
            }

            Section("Save As") {
                Picker("Save Mode", selection: $saveMode) {
                    ForEach(SaveMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if saveMode == .asMeal {
                    Picker("Meal Type", selection: $mealType) {
                        ForEach(MealType.allCases) { type in
                            Label(type.displayName, systemImage: type.icon).tag(type)
                        }
                    }
                }
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Scan Failed", systemImage: "exclamationmark.triangle.fill")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                if let image = viewModel.capturedImage {
                    Task { await viewModel.analyzeLabel(image) }
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func editableNutrientRow(_ name: String, value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            TextField("0", value: value, format: .number.precision(.fractionLength(1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)
        }
    }

    private func save() {
        switch saveMode {
        case .asMeal:
            viewModel.saveAsMeal(context: modelContext, mealType: mealType)
        case .asLabel:
            viewModel.saveAsLabel(context: modelContext)
        }
    }
}
