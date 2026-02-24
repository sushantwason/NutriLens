import SwiftUI
import SwiftData
import WidgetKit

struct TextFoodSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var searchService = TextFoodSearchService()
    @State private var searchText = ""
    @State private var selectedMealType: MealType = .suggestedForCurrentTime
    @State private var showConfirmation = false
    @State private var selectedDetent: PresentationDetent = .medium

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty && searchService.searchResults.isEmpty {
                    emptyPlaceholder
                } else if searchService.isSearching {
                    searchingView
                } else if searchService.searchResults.isEmpty && !searchText.isEmpty {
                    noResultsView
                } else {
                    resultsList
                }
            }
            .navigationTitle("Search Food")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search for a food...")
            .onSubmit(of: .search) {
                Task { await searchService.search(query: searchText) }
            }
            .onChange(of: searchText) { _, newValue in
                if newValue.isEmpty {
                    searchService.searchResults = []
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if showConfirmation {
                    confirmationToast
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: showConfirmation)
            .presentationDetents([.medium, .large], selection: $selectedDetent)
            .onChange(of: searchService.searchResults) { _, newResults in
                if !newResults.isEmpty {
                    withAnimation { selectedDetent = .large }
                }
            }
        }
    }

    // MARK: - Empty Placeholder

    private var emptyPlaceholder: some View {
        ContentUnavailableView {
            Label("Search for any food", systemImage: "fork.knife")
        } description: {
            Text("Type a food name to look up its nutrition information.")
        }
    }

    // MARK: - Searching

    private var searchingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Searching...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - No Results

    private var noResultsView: some View {
        ContentUnavailableView {
            Label("No Results", systemImage: "magnifyingglass")
        } description: {
            Text("No foods found for \"\(searchText)\". Try a different search term.")
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        List {
            Section {
                mealTypePicker
            }

            Section("Results") {
                ForEach(searchService.searchResults, id: \.fdcId) { result in
                    Button {
                        addFood(result)
                    } label: {
                        resultRow(result)
                    }
                    .tint(.primary)
                }
            }

            if let error = searchService.error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Meal Type Picker

    private var mealTypePicker: some View {
        Picker("Meal Type", selection: $selectedMealType) {
            ForEach(MealType.allCases) { type in
                Label(type.displayName, systemImage: type.icon).tag(type)
            }
        }
    }

    // MARK: - Result Row

    private func resultRow(_ result: FoodSearchResult) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(result.description)
                    .font(.body)
                    .lineLimit(2)

                if let brand = result.brandName, !brand.isEmpty {
                    Text(brand)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let serving = result.servingSize, !serving.isEmpty {
                    Text(serving)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text(result.calories.calorieString)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(.calorieColor)
                + Text(" kcal")
                    .font(.caption2)
                    .foregroundStyle(.calorieColor.opacity(0.7))

                HStack(spacing: 6) {
                    macroLabel("P", value: result.protein, color: .proteinColor)
                    macroLabel("C", value: result.carbs, color: .carbsColor)
                    macroLabel("F", value: result.fat, color: .fatColor)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func macroLabel(_ letter: String, value: Double, color: Color) -> some View {
        HStack(spacing: 1) {
            Text(value.wholeString)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
            Text(letter)
                .font(.caption2)
                .foregroundStyle(color.opacity(0.7))
        }
    }

    // MARK: - Confirmation Toast

    private var confirmationToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white)
            Text("Added to today's meals")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.nutriGreen, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .padding(.bottom, 16)
    }

    // MARK: - Add Food

    private func addFood(_ result: FoodSearchResult) {
        HapticService.buttonTap()

        let converted = searchService.toFoodItem(result)

        let meal = Meal(
            name: converted.name,
            mealType: selectedMealType,
            sourceType: .manual
        )

        let foodItem = FoodItem(
            name: converted.name,
            nutrients: converted.nutrients
        )

        meal.foodItems.append(foodItem)
        meal.recalculateTotals()
        meal.isConfirmedByUser = true

        modelContext.insert(meal)

        HapticService.mealSaved()
        WidgetCenter.shared.reloadAllTimelines()

        showConfirmation = true
        // Use Task.sleep instead of DispatchQueue to avoid retain issues if view is dismissed early
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            showConfirmation = false
            dismiss()
        }
    }
}

#Preview {
    TextFoodSearchView()
        .modelContainer(for: Meal.self, inMemory: true)
}
