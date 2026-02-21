import SwiftUI
import SwiftData

struct MealDetailView: View {
    let meal: Meal
    @Environment(\.modelContext) private var modelContext
    @State private var showRelogConfirmation = false

    var body: some View {
        List {
            // Photo
            if let photoData = meal.photoData, let uiImage = UIImage(data: photoData) {
                Section {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .listRowInsets(EdgeInsets())
                        .frame(maxWidth: .infinity)
                }
            }

            // Meal info
            Section("Meal Info") {
                LabeledContent("Name", value: meal.name)
                LabeledContent("Type") {
                    Label(meal.mealType.displayName, systemImage: meal.mealType.icon)
                }
                LabeledContent("Date", value: meal.timestamp.mediumDateString)
                LabeledContent("Time", value: meal.timestamp.shortTimeString)
                LabeledContent("Source") {
                    Text(sourceLabel)
                }
                if let confidence = meal.confidenceScore {
                    LabeledContent("AI Confidence") {
                        Text("\(Int(confidence * 100))%")
                            .foregroundStyle(confidence > 0.7 ? .green : confidence > 0.4 ? .orange : .red)
                    }
                }
            }

            // Ingredients
            Section("Ingredients (\(meal.foodItems.count))") {
                ForEach(meal.foodItems) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.name)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text("\(item.nutrients.calories.calorieString) kcal")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.calorieColor)
                        }
                        if let quantity = item.quantity {
                            Text(quantity)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 12) {
                            macroLabel("P", item.nutrients.proteinGrams, .proteinColor)
                            macroLabel("C", item.nutrients.carbsGrams, .carbsColor)
                            macroLabel("F", item.nutrients.fatGrams, .fatColor)
                        }
                        .font(.caption2)
                    }
                    .padding(.vertical, 2)
                }
            }

            // Totals
            Section("Total Nutrients") {
                nutrientRow("Calories", meal.totalCalories.calorieString, "kcal", .calorieColor)
                nutrientRow("Protein", meal.totalProteinGrams.oneDecimalString, "g", .proteinColor)
                nutrientRow("Carbs", meal.totalCarbsGrams.oneDecimalString, "g", .carbsColor)
                nutrientRow("Fat", meal.totalFatGrams.oneDecimalString, "g", .fatColor)
                nutrientRow("Fiber", meal.totalFiberGrams.oneDecimalString, "g", .secondary)
                nutrientRow("Sugar", meal.totalSugarGrams.oneDecimalString, "g", .secondary)
            }

            if let notes = meal.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                }
            }
        }
        .navigationTitle(meal.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    Button {
                        HapticService.buttonTap()
                        meal.isFavorite.toggle()
                        try? modelContext.save()
                    } label: {
                        Image(systemName: meal.isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(meal.isFavorite ? .nutriRed : .secondary)
                    }

                    Button {
                        let copy = meal.relogCopy()
                        modelContext.insert(copy)
                        try? modelContext.save()
                        HapticService.mealSaved()
                        showRelogConfirmation = true
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .alert("Meal Logged", isPresented: $showRelogConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("\(meal.name) has been logged again for today.")
        }
    }

    private var sourceLabel: String {
        switch meal.sourceType {
        case .photoAnalysis: return "AI Photo Analysis"
        case .nutritionLabel: return "Nutrition Label Scan"
        case .barcode: return "Barcode Scan"
        case .recipe: return "Recipe Analysis"
        case .manual: return "Manual Entry"
        }
    }

    private func macroLabel(_ letter: String, _ value: Double, _ color: Color) -> some View {
        Text("\(letter): \(value.oneDecimalString)g")
            .foregroundStyle(color)
    }

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
