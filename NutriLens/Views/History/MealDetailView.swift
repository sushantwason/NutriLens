import SwiftUI
import SwiftData

struct MealDetailView: View {
    let meal: Meal
    @Environment(\.modelContext) private var modelContext
    @State private var showRelogConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero: photo with calorie overlay
                heroSection

                // Macro rings summary
                macroSummary
                    .padding(.horizontal)
                    .padding(.top, 12)

                // Meal info row
                mealInfoRow
                    .padding(.horizontal)
                    .padding(.top, 12)

                // Food items
                foodItemsSection
                    .padding(.horizontal)
                    .padding(.top, 16)

                // Fiber & Sugar (secondary nutrients)
                secondaryNutrients
                    .padding(.horizontal)
                    .padding(.top, 12)

                // Notes
                if let notes = meal.notes, !notes.isEmpty {
                    notesSection(notes)
                        .padding(.horizontal)
                        .padding(.top, 12)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
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

    // MARK: - Hero Section

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            if let photoData = meal.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
                    .overlay {
                        LinearGradient(
                            colors: [.clear, .clear, .black.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }

                // Calorie overlay on photo
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(meal.totalCalories.calorieString)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("kcal")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(16)
            } else {
                // No photo fallback
                HStack {
                    Image(systemName: meal.mealType.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(.nutriGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.totalCalories.calorieString)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text("kcal")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 0))
            }
        }
    }

    // MARK: - Macro Summary

    private var macroSummary: some View {
        HStack(spacing: 12) {
            macroRingCard("Protein", meal.totalProteinGrams, .proteinColor)
            macroRingCard("Carbs", meal.totalCarbsGrams, .carbsColor)
            macroRingCard("Fat", meal.totalFatGrams, .fatColor)
        }
    }

    private func macroRingCard(_ title: String, _ grams: Double, _ color: Color) -> some View {
        VStack(spacing: 4) {
            MacroRingView(
                progress: min(grams / 100, 1.0),
                color: color,
                lineWidth: 5,
                size: 44
            ) {
                Text(grams.oneDecimalString)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(grams.oneDecimalString)g")
                .font(.caption2.weight(.medium))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Meal Info Row

    private var mealInfoRow: some View {
        HStack(spacing: 12) {
            Image(systemName: meal.mealType.icon)
                .font(.title3)
                .foregroundStyle(.nutriGreen)
                .frame(width: 36, height: 36)
                .background(.nutriGreen.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(meal.mealType.displayName)
                    .font(.subheadline.weight(.medium))
                Text("\(meal.timestamp.mediumDateString) at \(meal.timestamp.shortTimeString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let confidence = meal.confidenceScore {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text("\(Int(confidence * 100))%")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(confidence > 0.7 ? .green : confidence > 0.4 ? .orange : .red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (confidence > 0.7 ? Color.green : confidence > 0.4 ? .orange : .red).opacity(0.12),
                    in: Capsule()
                )
            }

            sourceIcon
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var sourceIcon: some View {
        let (icon, label) = sourceInfo
        return Image(systemName: icon)
            .font(.caption)
            .foregroundStyle(.secondary)
            .help(label)
    }

    private var sourceInfo: (String, String) {
        switch meal.sourceType {
        case .photoAnalysis: return ("camera.fill", "AI Photo Analysis")
        case .nutritionLabel: return ("doc.text.viewfinder", "Nutrition Label Scan")
        case .barcode: return ("barcode.viewfinder", "Barcode Scan")
        case .recipe: return ("book.fill", "Recipe Analysis")
        case .manual: return ("pencil", "Manual Entry")
        }
    }

    // MARK: - Food Items

    private var foodItemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Ingredients")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(meal.foodItems.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(meal.foodItems) { item in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        if let quantity = item.quantity {
                            Text(quantity)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        macroTag("P", item.nutrients.proteinGrams, .proteinColor)
                        macroTag("C", item.nutrients.carbsGrams, .carbsColor)
                        macroTag("F", item.nutrients.fatGrams, .fatColor)
                    }

                    Text("\(item.nutrients.calories.calorieString)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.calorieColor)
                        .frame(minWidth: 32, alignment: .trailing)
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func macroTag(_ letter: String, _ value: Double, _ color: Color) -> some View {
        Text("\(letter):\(value.oneDecimalString)")
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.1), in: Capsule())
    }

    // MARK: - Secondary Nutrients

    private var secondaryNutrients: some View {
        HStack(spacing: 16) {
            secondaryNutrientPill("Fiber", meal.totalFiberGrams)
            secondaryNutrientPill("Sugar", meal.totalSugarGrams)
        }
    }

    private func secondaryNutrientPill(_ name: String, _ value: Double) -> some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value.oneDecimalString)g")
                .font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Notes

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(notes)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
