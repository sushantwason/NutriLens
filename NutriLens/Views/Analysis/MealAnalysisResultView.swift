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
            // Photo (compact)
            if let image = viewModel.capturedImage {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .listRowInsets(EdgeInsets())
                        .frame(maxWidth: .infinity)
                }
            }

            // Inline macro summary bar (replaces bottom Total Nutrients)
            Section {
                macroSummaryBar
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
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                            Text("\(Int(viewModel.confidenceScore * 100))%")
                        }
                        .foregroundStyle(viewModel.confidenceScore > 0.7 ? .green : viewModel.confidenceScore > 0.4 ? .orange : .red)
                    }
                }
            }

            // Dietary alerts
            if !dietaryAlerts.isEmpty {
                Section {
                    DietaryAlertBanner(alerts: dietaryAlerts)
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

            // Disclaimer
            Section {
                Text("Nutritional values are AI-generated estimates and may differ from actual content. Not medical advice.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Feedback banner (shown after save)
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

    // MARK: - Macro Summary Bar

    private var macroSummaryBar: some View {
        HStack(spacing: 0) {
            macroPill(
                icon: "flame.fill",
                value: viewModel.totalNutrients.calories.calorieString,
                unit: "kcal",
                color: .calorieColor
            )

            Divider().frame(height: 28)

            macroPill(
                icon: nil,
                value: viewModel.totalNutrients.proteinGrams.oneDecimalString,
                unit: "P",
                color: .proteinColor
            )

            Divider().frame(height: 28)

            macroPill(
                icon: nil,
                value: viewModel.totalNutrients.carbsGrams.oneDecimalString,
                unit: "C",
                color: .carbsColor
            )

            Divider().frame(height: 28)

            macroPill(
                icon: nil,
                value: viewModel.totalNutrients.fatGrams.oneDecimalString,
                unit: "F",
                color: .fatColor
            )

            Divider().frame(height: 28)

            macroPill(
                icon: nil,
                value: viewModel.totalNutrients.sugarGrams.oneDecimalString,
                unit: "S",
                color: .sugarColor
            )
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
    }

    private func macroPill(icon: String?, value: String, unit: String, color: Color) -> some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
            }
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(unit)
                .font(.caption2.weight(.medium))
                .foregroundStyle(color.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
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
}
