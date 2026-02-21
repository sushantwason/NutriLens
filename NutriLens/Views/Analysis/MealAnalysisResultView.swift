import SwiftUI
import SwiftData

struct MealAnalysisResultView: View {
    @Bindable var viewModel: MealAnalysisViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthKitManager.self) private var healthKitManager
    @Query private var profiles: [UserProfile]

    private var dietaryAlerts: [DietaryAlertChecker.Alert] {
        DietaryAlertChecker.check(
            items: viewModel.foodItems,
            flags: viewModel.dietaryFlags,
            restrictions: profiles.first?.dietaryRestrictions ?? []
        )
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
            .navigationTitle("Meal Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.showFeedbackBanner ? "Done" : "Cancel") {
                        dismiss()
                    }
                }
                if viewModel.analysisState == .success && !viewModel.showFeedbackBanner {
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

    // MARK: - Analyzing

    private var analyzingView: some View {
        VStack(spacing: 20) {
            if let image = viewModel.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            ProgressView("Analyzing your meal...")
                .font(.headline)
        }
        .padding()
    }

    // MARK: - Result

    private var resultView: some View {
        List {
            // Photo section
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

            // Meal info
            Section("Meal Info") {
                TextField("Meal Name", text: $viewModel.mealName)

                Picker("Meal Type", selection: $viewModel.mealType) {
                    ForEach(MealType.allCases) { type in
                        Label(type.displayName, systemImage: type.icon).tag(type)
                    }
                }

                if viewModel.confidenceScore > 0 {
                    HStack {
                        Text("AI Confidence")
                        Spacer()
                        Text("\(Int(viewModel.confidenceScore * 100))%")
                            .foregroundStyle(viewModel.confidenceScore > 0.7 ? .green : viewModel.confidenceScore > 0.4 ? .orange : .red)
                    }
                }
            }

            // Food items
            Section("Detected Foods") {
                ForEach($viewModel.foodItems) { $item in
                    FoodItemEditRow(item: $item)
                }
                .onDelete { offsets in
                    viewModel.removeItems(at: offsets)
                }

                Button {
                    viewModel.addEmptyItem()
                } label: {
                    Label("Add Item", systemImage: "plus.circle.fill")
                }
            }

            // Dietary alerts
            if !dietaryAlerts.isEmpty {
                Section {
                    DietaryAlertBanner(alerts: dietaryAlerts)
                }
            }

            // Totals
            Section("Total Nutrients") {
                nutrientRow("Calories", viewModel.totalNutrients.calories.calorieString, "kcal", .calorieColor)
                nutrientRow("Protein", viewModel.totalNutrients.proteinGrams.oneDecimalString, "g", .proteinColor)
                nutrientRow("Carbs", viewModel.totalNutrients.carbsGrams.oneDecimalString, "g", .carbsColor)
                nutrientRow("Fat", viewModel.totalNutrients.fatGrams.oneDecimalString, "g", .fatColor)
                nutrientRow("Fiber", viewModel.totalNutrients.fiberGrams.oneDecimalString, "g", .secondary)
                nutrientRow("Sugar", viewModel.totalNutrients.sugarGrams.oneDecimalString, "g", .secondary)
            }

            // Feedback banner (shown after save)
            if viewModel.showFeedbackBanner {
                Section {
                    AccuracyFeedbackBanner { rating in
                        viewModel.rateAccuracy(rating, context: modelContext)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Analysis Failed", systemImage: "exclamationmark.triangle.fill")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                if let image = viewModel.capturedImage {
                    Task { await viewModel.analyzePhoto(image) }
                }
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
