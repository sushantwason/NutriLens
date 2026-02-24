import SwiftUI
import SwiftData
import WidgetKit

struct MealHistoryView: View {
    @Query(filter: #Predicate<Meal> { $0.isConfirmedByUser == true },
           sort: \Meal.timestamp, order: .reverse)
    private var meals: [Meal]

    @Query(filter: #Predicate<Meal> { $0.isConfirmedByUser == true && $0.isFavorite == true },
           sort: \Meal.timestamp, order: .reverse)
    private var favoriteMeals: [Meal]

    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""

    private var filteredMeals: [Meal] {
        if searchText.isEmpty { return meals }
        return meals.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var groupedMeals: [(String, [Meal])] {
        let grouped = Dictionary(grouping: filteredMeals) { meal in
            meal.timestamp.startOfDay.sectionHeaderString
        }
        // Sort groups by the first meal's timestamp (most recent first)
        return grouped.sorted { lhs, rhs in
            guard let lhsDate = lhs.value.first?.timestamp,
                  let rhsDate = rhs.value.first?.timestamp else { return false }
            return lhsDate > rhsDate
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if meals.isEmpty {
                    ContentUnavailableView(
                        "No Meals Logged",
                        systemImage: "fork.knife",
                        description: Text("Your meal history will appear here after you scan your first meal.")
                    )
                } else {
                    mealList
                }
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search meals")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var mealList: some View {
        List {
            // Favorites section
            if !favoriteMeals.isEmpty && searchText.isEmpty {
                Section {
                    favoritesSection
                } header: {
                    HStack {
                        Text("Favorites")
                        Spacer()
                        Text("\(favoriteMeals.count)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.quaternary, in: Capsule())
                    }
                }
            }

            // Date-grouped sections
            ForEach(groupedMeals, id: \.0) { section, sectionMeals in
                Section(section) {
                    ForEach(sectionMeals) { meal in
                        mealRow(meal)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var favoritesSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(favoriteMeals) { meal in
                    FavoriteCardView(meal: meal, onRelog: {
                        relogMeal(meal)
                    })
                    .contextMenu {
                        Button {
                            relogMeal(meal)
                        } label: {
                            Label("One More", systemImage: "plus.circle")
                        }

                        Button {
                            meal.isFavorite = false
                            try? modelContext.save()
                        } label: {
                            Label("Unfavorite", systemImage: "heart.slash")
                        }

                        Divider()

                        Button(role: .destructive) {
                            HapticService.mealDeleted()
                            modelContext.delete(meal)
                            try? modelContext.save()
                            WidgetCenter.shared.reloadAllTimelines()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
    }

    private func mealRow(_ meal: Meal) -> some View {
        NavigationLink(destination: MealDetailView(meal: meal)) {
            MealHistoryRow(meal: meal)
        }
        .swipeActions(edge: .leading) {
            Button {
                relogMeal(meal)
            } label: {
                Label("One More", systemImage: "plus.circle")
            }
            .tint(.nutriGreen)
        }
        .swipeActions(edge: .trailing) {
            Button {
                meal.isFavorite.toggle()
                try? modelContext.save()
            } label: {
                Label(
                    meal.isFavorite ? "Unfavorite" : "Favorite",
                    systemImage: meal.isFavorite ? "heart.slash" : "heart"
                )
            }
            .tint(.nutriRed)

            Button(role: .destructive) {
                HapticService.mealDeleted()
                modelContext.delete(meal)
                try? modelContext.save()
                WidgetCenter.shared.reloadAllTimelines()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button {
                relogMeal(meal)
            } label: {
                Label("One More", systemImage: "plus.circle")
            }

            Button {
                meal.isFavorite.toggle()
                try? modelContext.save()
            } label: {
                Label(
                    meal.isFavorite ? "Unfavorite" : "Favorite",
                    systemImage: meal.isFavorite ? "heart.slash" : "heart"
                )
            }

            Divider()

            Button(role: .destructive) {
                HapticService.mealDeleted()
                modelContext.delete(meal)
                try? modelContext.save()
                WidgetCenter.shared.reloadAllTimelines()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func relogMeal(_ meal: Meal) {
        let copy = meal.relogCopy()
        modelContext.insert(copy)
        try? modelContext.save()
        HapticService.mealSaved()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

struct MealHistoryRow: View {
    let meal: Meal

    var body: some View {
        HStack(spacing: 12) {
            if let photoData = meal.photoData,
               let uiImage = ThumbnailCache.shared.thumbnail(for: photoData, size: 100) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: meal.mealType.icon)
                    .font(.title3)
                    .foregroundStyle(.nutriGreen)
                    .frame(width: 50, height: 50)
                    .background(.nutriGreen.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(meal.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    if meal.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption2)
                            .foregroundStyle(.nutriRed)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: meal.mealType.icon)
                        .font(.caption2)
                    Text(meal.mealType.displayName)
                        .font(.caption)
                    Text("·")
                    Text(meal.timestamp.shortTimeString)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(meal.totalCalories.calorieString) kcal")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.calorieColor)
        }
        .padding(.vertical, 2)
    }
}

struct FavoriteCardView: View {
    let meal: Meal
    var onRelog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let photoData = meal.photoData,
                   let uiImage = ThumbnailCache.shared.thumbnail(for: photoData, size: 72) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: meal.mealType.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.nutriGreen)
                        .frame(width: 36, height: 36)
                        .background(.nutriGreen.opacity(0.15),
                                    in: RoundedRectangle(cornerRadius: 8))
                }

                Spacer()

                Button {
                    onRelog()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.nutriGreen)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Log \(meal.name) again")
            }

            Text(meal.name)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)

            Text("\(meal.totalCalories.calorieString) kcal")
                .font(.caption.weight(.bold))
                .foregroundStyle(.calorieColor)

            HStack(spacing: 6) {
                macroLabel("P", meal.totalProteinGrams, .proteinColor)
                macroLabel("C", meal.totalCarbsGrams, .carbsColor)
                macroLabel("F", meal.totalFatGrams, .fatColor)
                macroLabel("S", meal.totalSugarGrams, .sugarColor)
            }
        }
        .padding(12)
        .frame(width: 140, height: 145)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(meal.name), \(meal.totalCalories.calorieString) kilocalories")
        .accessibilityHint("Long press for options, or tap plus to log again")
    }

    private func macroLabel(_ letter: String, _ value: Double, _ color: Color) -> some View {
        Text("\(letter):\(value.wholeString)")
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .foregroundStyle(color)
    }
}

#Preview {
    MealHistoryView()
        .modelContainer(for: Meal.self, inMemory: true)
}
