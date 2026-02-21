import SwiftUI
import SwiftData

struct RecipeAnalysisResultView: View {
    @Bindable var viewModel: RecipeAnalysisViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(HealthKitManager.self) private var healthKitManager

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
            .navigationTitle("Recipe Analysis")
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

            ProgressView("Analyzing recipe...")
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

            // Recipe info
            Section("Recipe Info") {
                TextField("Recipe Name", text: $viewModel.mealName)

                Stepper("Servings: \(viewModel.estimatedServings)", value: $viewModel.estimatedServings, in: 1...20)

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

            // Dietary flags
            if !viewModel.dietaryFlags.isEmpty {
                Section("Dietary Flags") {
                    FlowLayout(spacing: 6) {
                        ForEach(viewModel.dietaryFlags, id: \.self) { flag in
                            Text(flag)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.nutriOrange, in: Capsule())
                        }
                    }
                }
            }

            // Ingredients
            Section("Ingredients (Full Recipe)") {
                ForEach($viewModel.foodItems) { $item in
                    FoodItemEditRow(item: $item)
                }
                .onDelete { offsets in
                    viewModel.removeItems(at: offsets)
                }

                Button {
                    viewModel.addEmptyItem()
                } label: {
                    Label("Add Ingredient", systemImage: "plus.circle.fill")
                }
            }

            // Per-serving totals
            Section("Nutrients Per Serving") {
                let ps = viewModel.perServingNutrients
                nutrientRow("Calories", ps.calories.calorieString, "kcal", .calorieColor)
                nutrientRow("Protein", ps.proteinGrams.oneDecimalString, "g", .proteinColor)
                nutrientRow("Carbs", ps.carbsGrams.oneDecimalString, "g", .carbsColor)
                nutrientRow("Fat", ps.fatGrams.oneDecimalString, "g", .fatColor)
                nutrientRow("Fiber", ps.fiberGrams.oneDecimalString, "g", .secondary)
                nutrientRow("Sugar", ps.sugarGrams.oneDecimalString, "g", .secondary)
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
                    Task { await viewModel.analyzeRecipe(image) }
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

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
