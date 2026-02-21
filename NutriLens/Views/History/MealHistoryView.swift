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
                        ExportView()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private var mealList: some View {
        List {
            // Favorites section
            if !favoriteMeals.isEmpty && searchText.isEmpty {
                Section("Favorites") {
                    ForEach(favoriteMeals) { meal in
                        NavigationLink(destination: MealDetailView(meal: meal)) {
                            MealHistoryRow(meal: meal)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                relogMeal(meal)
                            } label: {
                                Label("Log Again", systemImage: "arrow.clockwise")
                            }
                            .tint(.nutriGreen)
                        }
                    }
                }
            }

            // Date-grouped sections
            ForEach(groupedMeals, id: \.0) { section, sectionMeals in
                Section(section) {
                    ForEach(sectionMeals) { meal in
                        NavigationLink(destination: MealDetailView(meal: meal)) {
                            MealHistoryRow(meal: meal)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                relogMeal(meal)
                            } label: {
                                Label("Log Again", systemImage: "arrow.clockwise")
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
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
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
            if let photoData = meal.photoData, let uiImage = UIImage(data: photoData) {
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

#Preview {
    MealHistoryView()
        .modelContainer(for: Meal.self, inMemory: true)
}
