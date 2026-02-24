import Foundation
import SwiftData

enum NutritionInsightsEngine {

    // MARK: - Insight Types

    struct InsightCard: Identifiable {
        let id = UUID()
        let type: InsightType
        let icon: String
        let iconColor: String
        let title: String
        let message: String
        let severity: Severity
    }

    enum InsightType {
        case eatingPattern
        case macroBalance
        case calorieConsistency
        case timingInsight
        case deficiencyAlert
        case streakTrend
        case goalSuggestion
        case correlation
    }

    enum Severity: Int, Comparable {
        case info = 0
        case warning = 1
        case alert = 2

        static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    // MARK: - Internal Helpers

    /// A single day's aggregated nutrition data used across analysis functions.
    private struct DaySummary {
        let date: Date
        let meals: [Meal]
        let totalCalories: Double
        let totalProtein: Double
        let totalCarbs: Double
        let totalFat: Double
        let totalFiber: Double
        let totalSugar: Double
        let totalSodium: Double
        let totalSaturatedFat: Double
    }

    // MARK: - Cache

    private static var cachedInsights: [InsightCard]?
    private static var cacheKey: (mealCount: Int, date: Date)?

    /// Invalidate the cache (call when meals are added/deleted)
    static func invalidateCache() {
        cachedInsights = nil
        cacheKey = nil
    }

    // MARK: - Main Analysis

    @MainActor
    static func generateInsights(context: ModelContext, goal: DailyGoal?) async -> [InsightCard] {
        let meals = fetchConfirmedMeals(context: context)

        // Return cached results if meal count hasn't changed and still same day
        let today = Calendar.current.startOfDay(for: Date())
        if let cached = cachedInsights, let key = cacheKey,
           key.mealCount == meals.count, Calendar.current.isDate(key.date, inSameDayAs: today) {
            return cached
        }

        guard !meals.isEmpty else {
            return [InsightCard(
                type: .eatingPattern,
                icon: "fork.knife.circle",
                iconColor: "nutriBlue",
                title: "Start Logging Meals",
                message: "Log your first meal to begin receiving personalized nutrition insights.",
                severity: .info
            )]
        }

        let daySummaries = buildDaySummaries(from: meals)

        var insights: [InsightCard] = []
        insights.append(contentsOf: analyzeEatingPatterns(meals: meals, daySummaries: daySummaries))
        insights.append(contentsOf: analyzeTimingInsights(meals: meals))
        insights.append(contentsOf: analyzeMacroBalance(daySummaries: daySummaries, goal: goal))
        insights.append(contentsOf: analyzeCalorieConsistency(daySummaries: daySummaries, goal: goal))
        insights.append(contentsOf: analyzeDeficiencies(daySummaries: daySummaries))
        insights.append(contentsOf: analyzeCorrelations(meals: meals, daySummaries: daySummaries))
        insights.append(contentsOf: analyzeGoalSuggestions(daySummaries: daySummaries, goal: goal))

        // Sort by severity descending: alert first, then warning, then info
        insights.sort { $0.severity > $1.severity }

        // Cache the results
        cachedInsights = insights
        cacheKey = (mealCount: meals.count, date: today)

        return insights
    }

    // MARK: - Data Fetching

    private static func fetchConfirmedMeals(context: ModelContext) -> [Meal] {
        var descriptor = FetchDescriptor<Meal>(
            predicate: #Predicate<Meal> { $0.isConfirmedByUser == true },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        descriptor.fetchLimit = 5000
        do {
            return try context.fetch(descriptor)
        } catch {
            return []
        }
    }

    private static func buildDaySummaries(from meals: [Meal]) -> [DaySummary] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: meals) { meal in
            calendar.startOfDay(for: meal.timestamp)
        }

        return grouped.map { date, dayMeals in
            // Aggregate nutrient totals from food items for sodium/saturated fat
            var totalSodium: Double = 0
            var totalSaturatedFat: Double = 0
            for meal in dayMeals {
                for item in meal.foodItems {
                    totalSodium += item.nutrients.sodiumMilligrams
                    totalSaturatedFat += item.nutrients.saturatedFatGrams
                }
            }

            return DaySummary(
                date: date,
                meals: dayMeals,
                totalCalories: dayMeals.reduce(0) { $0 + $1.totalCalories },
                totalProtein: dayMeals.reduce(0) { $0 + $1.totalProteinGrams },
                totalCarbs: dayMeals.reduce(0) { $0 + $1.totalCarbsGrams },
                totalFat: dayMeals.reduce(0) { $0 + $1.totalFatGrams },
                totalFiber: dayMeals.reduce(0) { $0 + $1.totalFiberGrams },
                totalSugar: dayMeals.reduce(0) { $0 + $1.totalSugarGrams },
                totalSodium: totalSodium,
                totalSaturatedFat: totalSaturatedFat
            )
        }.sorted { $0.date < $1.date }
    }

    // MARK: - 1. Eating Pattern Analysis

    private static func analyzeEatingPatterns(meals: [Meal], daySummaries: [DaySummary]) -> [InsightCard] {
        guard daySummaries.count >= 2 else { return [] }

        var insights: [InsightCard] = []
        let calendar = Calendar.current

        // Which meal type is logged most and least
        let mealTypeCounts = Dictionary(grouping: meals) { $0.mealType }
            .mapValues { $0.count }
        let sortedTypes = mealTypeCounts.sorted { $0.value > $1.value }

        if let most = sortedTypes.first, let least = sortedTypes.last, sortedTypes.count >= 2 {
            if least.value == 0 || (most.value > least.value * 3) {
                insights.append(InsightCard(
                    type: .eatingPattern,
                    icon: "chart.bar.fill",
                    iconColor: "nutriBlue",
                    title: "Meal Type Imbalance",
                    message: "You log \(most.key.displayName.lowercased()) most often (\(most.value) times) but rarely log \(least.key.displayName.lowercased()) (\(least.value) times). Try logging all your meals for more accurate tracking.",
                    severity: .info
                ))
            }
        }

        // Average meals per day
        let totalDays = daySummaries.count
        let avgMeals = Double(meals.count) / Double(totalDays)
        if avgMeals < 2.0 {
            insights.append(InsightCard(
                type: .eatingPattern,
                icon: "exclamationmark.triangle.fill",
                iconColor: "nutriOrange",
                title: "Low Meal Frequency",
                message: "You're averaging \(String(format: "%.1f", avgMeals)) meals per day. Eating at least 3 meals helps maintain stable energy levels.",
                severity: .warning
            ))
        } else if avgMeals >= 3.0 && avgMeals <= 5.0 {
            insights.append(InsightCard(
                type: .eatingPattern,
                icon: "checkmark.circle.fill",
                iconColor: "nutriGreen",
                title: "Good Meal Frequency",
                message: "You're averaging \(String(format: "%.1f", avgMeals)) meals per day, which is a healthy eating pattern.",
                severity: .info
            ))
        }

        // Weekend vs weekday differences
        let weekdayMeals = meals.filter {
            let weekday = calendar.component(.weekday, from: $0.timestamp)
            return weekday >= 2 && weekday <= 6 // Mon-Fri
        }
        let weekendMeals = meals.filter {
            let weekday = calendar.component(.weekday, from: $0.timestamp)
            return weekday == 1 || weekday == 7 // Sat-Sun
        }

        let weekdayDays = Set(daySummaries.filter {
            let wd = calendar.component(.weekday, from: $0.date)
            return wd >= 2 && wd <= 6
        }.map { $0.date }).count
        let weekendDays = Set(daySummaries.filter {
            let wd = calendar.component(.weekday, from: $0.date)
            return wd == 1 || wd == 7
        }.map { $0.date }).count

        if weekdayDays > 0 && weekendDays > 0 {
            let avgWeekdayCals = weekdayMeals.reduce(0.0) { $0 + $1.totalCalories } / Double(weekdayDays)
            let avgWeekendCals = weekendMeals.reduce(0.0) { $0 + $1.totalCalories } / Double(weekendDays)

            if avgWeekendCals > 0 && avgWeekdayCals > 0 {
                let diff = ((avgWeekendCals - avgWeekdayCals) / avgWeekdayCals) * 100
                if diff > 20 {
                    insights.append(InsightCard(
                        type: .eatingPattern,
                        icon: "calendar.badge.exclamationmark",
                        iconColor: "nutriOrange",
                        title: "Weekend Calorie Spike",
                        message: "You eat about \(Int(diff))% more calories on weekends (\(Int(avgWeekendCals)) cal) vs weekdays (\(Int(avgWeekdayCals)) cal). Planning weekend meals can help maintain consistency.",
                        severity: .warning
                    ))
                } else if diff < -20 {
                    insights.append(InsightCard(
                        type: .eatingPattern,
                        icon: "calendar",
                        iconColor: "nutriBlue",
                        title: "Lower Weekend Intake",
                        message: "You eat about \(Int(abs(diff)))% fewer calories on weekends. Make sure you're fueling adequately throughout the week.",
                        severity: .info
                    ))
                }
            }
        }

        return insights
    }

    // MARK: - 2. Timing Insights

    private static func analyzeTimingInsights(meals: [Meal]) -> [InsightCard] {
        guard meals.count >= 3 else { return [] }

        var insights: [InsightCard] = []
        let calendar = Calendar.current

        // Calorie distribution: morning (before noon) vs evening (after 5pm)
        let morningMeals = meals.filter {
            let hour = calendar.component(.hour, from: $0.timestamp)
            return hour < 12
        }
        let eveningMeals = meals.filter {
            let hour = calendar.component(.hour, from: $0.timestamp)
            return hour >= 17
        }

        let morningCals = morningMeals.reduce(0.0) { $0 + $1.totalCalories }
        let eveningCals = eveningMeals.reduce(0.0) { $0 + $1.totalCalories }
        let totalCals = meals.reduce(0.0) { $0 + $1.totalCalories }

        if totalCals > 0 {
            let eveningPercent = (eveningCals / totalCals) * 100
            let morningPercent = (morningCals / totalCals) * 100

            if eveningPercent > 60 {
                insights.append(InsightCard(
                    type: .timingInsight,
                    icon: "moon.stars.fill",
                    iconColor: "nutriOrange",
                    title: "Evening-Heavy Eating",
                    message: "About \(Int(eveningPercent))% of your calories come after 5 PM. Shifting some intake earlier may improve sleep and digestion.",
                    severity: .warning
                ))
            } else if morningPercent > 50 {
                insights.append(InsightCard(
                    type: .timingInsight,
                    icon: "sunrise.fill",
                    iconColor: "nutriGreen",
                    title: "Front-Loaded Eating",
                    message: "You eat \(Int(morningPercent))% of your calories before noon. This is associated with better energy throughout the day.",
                    severity: .info
                ))
            }
        }

        // Late night eating detection (after 9 PM)
        let lateNightMeals = meals.filter {
            let hour = calendar.component(.hour, from: $0.timestamp)
            return hour >= 21
        }

        if !lateNightMeals.isEmpty {
            let latePercent = (Double(lateNightMeals.count) / Double(meals.count)) * 100
            if latePercent > 10 {
                let avgLateCalories = lateNightMeals.reduce(0.0) { $0 + $1.totalCalories } / Double(lateNightMeals.count)
                insights.append(InsightCard(
                    type: .timingInsight,
                    icon: "moon.zzz.fill",
                    iconColor: "nutriRed",
                    title: "Late Night Eating",
                    message: "\(lateNightMeals.count) meals logged after 9 PM, averaging \(Int(avgLateCalories)) calories each. Late eating can affect sleep quality and metabolism.",
                    severity: .warning
                ))
            }
        }

        // Meal gap analysis: find days where longest gap between meals exceeds 7 hours
        let mealsByDay = Dictionary(grouping: meals) { meal in
            calendar.startOfDay(for: meal.timestamp)
        }

        var longGapDays = 0
        var totalDaysChecked = 0
        for (_, dayMeals) in mealsByDay where dayMeals.count >= 2 {
            totalDaysChecked += 1
            let sorted = dayMeals.sorted { $0.timestamp < $1.timestamp }
            for i in 1..<sorted.count {
                let gap = sorted[i].timestamp.timeIntervalSince(sorted[i - 1].timestamp) / 3600
                if gap > 7 {
                    longGapDays += 1
                    break
                }
            }
        }

        if totalDaysChecked > 0 {
            let gapPercent = (Double(longGapDays) / Double(totalDaysChecked)) * 100
            if gapPercent > 40 {
                insights.append(InsightCard(
                    type: .timingInsight,
                    icon: "clock.badge.exclamationmark",
                    iconColor: "nutriOrange",
                    title: "Long Gaps Between Meals",
                    message: "On \(Int(gapPercent))% of days, you go more than 7 hours between meals. Regular spacing helps maintain steady blood sugar levels.",
                    severity: .warning
                ))
            }
        }

        return insights
    }

    // MARK: - 3. Macro Balance Alerts

    private static func analyzeMacroBalance(daySummaries: [DaySummary], goal: DailyGoal?) -> [InsightCard] {
        guard let goal = goal, daySummaries.count >= 3 else { return [] }

        var insights: [InsightCard] = []
        let dayCount = Double(daySummaries.count)

        let avgProtein = daySummaries.reduce(0.0) { $0 + $1.totalProtein } / dayCount
        let avgCarbs = daySummaries.reduce(0.0) { $0 + $1.totalCarbs } / dayCount
        let avgFat = daySummaries.reduce(0.0) { $0 + $1.totalFat } / dayCount
        let avgSugar = daySummaries.reduce(0.0) { $0 + $1.totalSugar } / dayCount

        // Protein analysis
        if goal.proteinGramsTarget > 0 {
            let proteinPercent = (avgProtein / goal.proteinGramsTarget) * 100
            if proteinPercent < 70 {
                insights.append(InsightCard(
                    type: .macroBalance,
                    icon: "bolt.fill",
                    iconColor: "nutriRed",
                    title: "Protein Significantly Low",
                    message: "You're averaging \(Int(avgProtein))g protein per day, which is \(Int(100 - proteinPercent))% below your \(Int(goal.proteinGramsTarget))g target. Protein is essential for muscle maintenance and satiety.",
                    severity: .alert
                ))
            } else if proteinPercent < 85 {
                insights.append(InsightCard(
                    type: .macroBalance,
                    icon: "bolt.fill",
                    iconColor: "nutriOrange",
                    title: "Protein Below Target",
                    message: "You're averaging \(Int(avgProtein))g protein per day, about \(Int(100 - proteinPercent))% below your \(Int(goal.proteinGramsTarget))g target. Consider adding protein-rich foods like eggs, lean meat, or legumes.",
                    severity: .warning
                ))
            }
        }

        // Carbs analysis
        if goal.carbsGramsTarget > 0 {
            let carbsPercent = (avgCarbs / goal.carbsGramsTarget) * 100
            if carbsPercent > 130 {
                insights.append(InsightCard(
                    type: .macroBalance,
                    icon: "leaf.fill",
                    iconColor: "nutriOrange",
                    title: "Carbs Over Target",
                    message: "You're averaging \(Int(avgCarbs))g carbs per day, about \(Int(carbsPercent - 100))% above your \(Int(goal.carbsGramsTarget))g target. Consider swapping refined carbs for whole grains and vegetables.",
                    severity: .warning
                ))
            } else if carbsPercent < 60 {
                insights.append(InsightCard(
                    type: .macroBalance,
                    icon: "leaf.fill",
                    iconColor: "nutriOrange",
                    title: "Carbs Significantly Low",
                    message: "You're averaging only \(Int(avgCarbs))g carbs per day against a \(Int(goal.carbsGramsTarget))g target. Carbs are your body's primary energy source.",
                    severity: .warning
                ))
            }
        }

        // Fat analysis
        if goal.fatGramsTarget > 0 {
            let fatPercent = (avgFat / goal.fatGramsTarget) * 100
            if fatPercent > 130 {
                insights.append(InsightCard(
                    type: .macroBalance,
                    icon: "drop.fill",
                    iconColor: "nutriOrange",
                    title: "Fat Over Target",
                    message: "You're averaging \(Int(avgFat))g fat per day, about \(Int(fatPercent - 100))% above your \(Int(goal.fatGramsTarget))g target. Watch for hidden fats in sauces, dressings, and fried foods.",
                    severity: .warning
                ))
            }
        }

        // High sugar warning (> 50g daily average, WHO guideline)
        if avgSugar > 50 {
            insights.append(InsightCard(
                type: .macroBalance,
                icon: "cube.fill",
                iconColor: "nutriRed",
                title: "High Sugar Intake",
                message: "You're averaging \(Int(avgSugar))g of sugar per day. The WHO recommends keeping added sugar under 50g. Check for hidden sugars in drinks, sauces, and packaged foods.",
                severity: .alert
            ))
        } else if avgSugar > 36 {
            insights.append(InsightCard(
                type: .macroBalance,
                icon: "cube.fill",
                iconColor: "nutriOrange",
                title: "Moderate Sugar Intake",
                message: "You're averaging \(Int(avgSugar))g of sugar per day. Consider reducing sugary drinks and snacks to stay well within recommended limits.",
                severity: .warning
            ))
        }

        return insights
    }

    // MARK: - 4. Calorie Consistency

    private static func analyzeCalorieConsistency(daySummaries: [DaySummary], goal: DailyGoal?) -> [InsightCard] {
        guard daySummaries.count >= 3 else { return [] }

        var insights: [InsightCard] = []
        let dayCount = Double(daySummaries.count)
        let dailyCals = daySummaries.map { $0.totalCalories }

        let avgCals = dailyCals.reduce(0, +) / dayCount

        // Standard deviation
        let variance = dailyCals.reduce(0.0) { $0 + pow($1 - avgCals, 2) } / dayCount
        let stdDev = sqrt(variance)
        let coeffOfVariation = avgCals > 0 ? (stdDev / avgCals) * 100 : 0

        if coeffOfVariation > 40 {
            insights.append(InsightCard(
                type: .calorieConsistency,
                icon: "waveform.path.ecg",
                iconColor: "nutriRed",
                title: "Highly Inconsistent Calories",
                message: "Your daily calorie intake varies widely (averaging \(Int(avgCals)) cal with swings of \u{00B1}\(Int(stdDev)) cal). Large fluctuations can affect energy, mood, and weight management.",
                severity: .alert
            ))
        } else if coeffOfVariation > 25 {
            insights.append(InsightCard(
                type: .calorieConsistency,
                icon: "waveform.path.ecg",
                iconColor: "nutriOrange",
                title: "Variable Calorie Intake",
                message: "Your calorie intake fluctuates moderately day to day (averaging \(Int(avgCals)) cal \u{00B1}\(Int(stdDev))). More consistency can help with energy levels.",
                severity: .warning
            ))
        } else if daySummaries.count >= 5 {
            insights.append(InsightCard(
                type: .calorieConsistency,
                icon: "checkmark.seal.fill",
                iconColor: "nutriGreen",
                title: "Consistent Eating",
                message: "Your daily calorie intake is consistent, averaging \(Int(avgCals)) calories with low variation. Great job maintaining a steady pattern.",
                severity: .info
            ))
        }

        // Over/under target frequency
        if let goal = goal, goal.calorieTarget > 0 {
            let overDays = dailyCals.filter { $0 > goal.calorieTarget * 1.1 }.count
            let underDays = dailyCals.filter { $0 < goal.calorieTarget * 0.7 }.count
            let total = dailyCals.count

            let overPercent = (Double(overDays) / Double(total)) * 100
            let underPercent = (Double(underDays) / Double(total)) * 100

            if overPercent > 50 {
                insights.append(InsightCard(
                    type: .calorieConsistency,
                    icon: "arrow.up.circle.fill",
                    iconColor: "nutriOrange",
                    title: "Frequently Over Target",
                    message: "You exceed your \(Int(goal.calorieTarget)) calorie target on \(Int(overPercent))% of days. Consider adjusting portions or reviewing your goal if it no longer fits.",
                    severity: .warning
                ))
            }

            if underPercent > 50 {
                insights.append(InsightCard(
                    type: .calorieConsistency,
                    icon: "arrow.down.circle.fill",
                    iconColor: "nutriOrange",
                    title: "Frequently Under Target",
                    message: "You're significantly under your \(Int(goal.calorieTarget)) calorie target on \(Int(underPercent))% of days. Consistently undereating can slow metabolism and affect energy.",
                    severity: .warning
                ))
            }
        }

        // Trend direction over the last 7 recorded days
        if daySummaries.count >= 5 {
            let recentDays = Array(daySummaries.suffix(7))
            let trend = calculateTrend(values: recentDays.map { $0.totalCalories })
            if trend > 50 {
                insights.append(InsightCard(
                    type: .calorieConsistency,
                    icon: "arrow.up.right",
                    iconColor: "nutriOrange",
                    title: "Calories Trending Up",
                    message: "Your calorie intake has been increasing over the past week, rising by about \(Int(trend)) calories per day. Keep an eye on portion sizes.",
                    severity: .info
                ))
            } else if trend < -50 {
                insights.append(InsightCard(
                    type: .calorieConsistency,
                    icon: "arrow.down.right",
                    iconColor: "nutriBlue",
                    title: "Calories Trending Down",
                    message: "Your calorie intake has been decreasing over the past week, dropping by about \(Int(abs(trend))) calories per day. Make sure you're eating enough to meet your needs.",
                    severity: .info
                ))
            }
        }

        return insights
    }

    // MARK: - 5. Deficiency Alerts

    private static func analyzeDeficiencies(daySummaries: [DaySummary]) -> [InsightCard] {
        guard daySummaries.count >= 3 else { return [] }

        var insights: [InsightCard] = []
        let dayCount = Double(daySummaries.count)

        let avgFiber = daySummaries.reduce(0.0) { $0 + $1.totalFiber } / dayCount
        let avgSaturatedFat = daySummaries.reduce(0.0) { $0 + $1.totalSaturatedFat } / dayCount
        let avgSodium = daySummaries.reduce(0.0) { $0 + $1.totalSodium } / dayCount

        // Low fiber warning (< 25g daily average)
        if avgFiber < 15 && avgFiber > 0 {
            insights.append(InsightCard(
                type: .deficiencyAlert,
                icon: "leaf.arrow.circlepath",
                iconColor: "nutriRed",
                title: "Very Low Fiber Intake",
                message: "You're averaging only \(Int(avgFiber))g of fiber per day. The recommended intake is 25-30g. Add fruits, vegetables, legumes, and whole grains to increase fiber.",
                severity: .alert
            ))
        } else if avgFiber < 25 && avgFiber >= 15 {
            insights.append(InsightCard(
                type: .deficiencyAlert,
                icon: "leaf.arrow.circlepath",
                iconColor: "nutriOrange",
                title: "Below-Average Fiber",
                message: "You're averaging \(Int(avgFiber))g of fiber per day, below the recommended 25g. Try adding an extra serving of vegetables or switching to whole grains.",
                severity: .warning
            ))
        }

        // High saturated fat warning (> 20g daily average)
        if avgSaturatedFat > 20 {
            insights.append(InsightCard(
                type: .deficiencyAlert,
                icon: "heart.fill",
                iconColor: "nutriRed",
                title: "High Saturated Fat",
                message: "You're averaging \(Int(avgSaturatedFat))g of saturated fat per day, above the recommended 20g limit. High intake is linked to increased cardiovascular risk. Consider lean proteins and plant-based fats.",
                severity: .alert
            ))
        } else if avgSaturatedFat > 15 {
            insights.append(InsightCard(
                type: .deficiencyAlert,
                icon: "heart.fill",
                iconColor: "nutriOrange",
                title: "Elevated Saturated Fat",
                message: "You're averaging \(Int(avgSaturatedFat))g of saturated fat per day. Try to keep it under 20g for better heart health.",
                severity: .warning
            ))
        }

        // High sodium warning (> 2300mg daily average)
        if avgSodium > 2300 {
            insights.append(InsightCard(
                type: .deficiencyAlert,
                icon: "drop.triangle.fill",
                iconColor: "nutriRed",
                title: "High Sodium Intake",
                message: "You're averaging \(Int(avgSodium))mg of sodium per day, exceeding the 2,300mg recommended limit. Excess sodium can raise blood pressure. Reduce processed and restaurant foods.",
                severity: .alert
            ))
        } else if avgSodium > 1800 {
            insights.append(InsightCard(
                type: .deficiencyAlert,
                icon: "drop.triangle.fill",
                iconColor: "nutriOrange",
                title: "Moderate Sodium Intake",
                message: "You're averaging \(Int(avgSodium))mg of sodium per day. While within limits, aiming for under 1,500mg is ideal for most adults.",
                severity: .warning
            ))
        }

        // Low protein per calorie ratio (protein should be roughly 15-35% of calories)
        let avgCalories = daySummaries.reduce(0.0) { $0 + $1.totalCalories } / dayCount
        let avgProtein = daySummaries.reduce(0.0) { $0 + $1.totalProtein } / dayCount
        if avgCalories > 0 {
            let proteinCalPercent = (avgProtein * 4) / avgCalories * 100
            if proteinCalPercent < 10 {
                insights.append(InsightCard(
                    type: .deficiencyAlert,
                    icon: "figure.stand",
                    iconColor: "nutriRed",
                    title: "Very Low Protein Ratio",
                    message: "Only \(Int(proteinCalPercent))% of your calories come from protein. Aim for at least 15% to support muscle maintenance and recovery.",
                    severity: .alert
                ))
            }
        }

        return insights
    }

    // MARK: - 6. Correlations

    private static func analyzeCorrelations(meals: [Meal], daySummaries: [DaySummary]) -> [InsightCard] {
        guard daySummaries.count >= 5 else { return [] }

        var insights: [InsightCard] = []

        // High calorie days correlate with specific meal types
        let avgCals = daySummaries.reduce(0.0) { $0 + $1.totalCalories } / Double(daySummaries.count)
        let highCalDays = daySummaries.filter { $0.totalCalories > avgCals * 1.25 }

        if highCalDays.count >= 2 {
            // Find which meal type contributes most on high-calorie days
            var mealTypeCalories: [MealType: (total: Double, count: Int)] = [:]
            for day in highCalDays {
                for meal in day.meals {
                    let existing = mealTypeCalories[meal.mealType] ?? (total: 0, count: 0)
                    mealTypeCalories[meal.mealType] = (total: existing.total + meal.totalCalories, count: existing.count + 1)
                }
            }

            if let biggest = mealTypeCalories.max(by: { $0.value.total < $1.value.total }) {
                let avgCalsForType = biggest.value.total / Double(biggest.value.count)
                insights.append(InsightCard(
                    type: .correlation,
                    icon: "link",
                    iconColor: "nutriPurple",
                    title: "High-Calorie Day Pattern",
                    message: "On your highest calorie days, \(biggest.key.displayName.lowercased()) tends to be the biggest contributor, averaging \(Int(avgCalsForType)) calories per meal.",
                    severity: .info
                ))
            }
        }

        // Snacking frequency impact
        let daysWithSnacks = daySummaries.filter { day in
            day.meals.contains { $0.mealType == .snack }
        }
        let daysWithoutSnacks = daySummaries.filter { day in
            !day.meals.contains { $0.mealType == .snack }
        }

        if daysWithSnacks.count >= 3 && daysWithoutSnacks.count >= 3 {
            let avgWithSnacks = daysWithSnacks.reduce(0.0) { $0 + $1.totalCalories } / Double(daysWithSnacks.count)
            let avgWithoutSnacks = daysWithoutSnacks.reduce(0.0) { $0 + $1.totalCalories } / Double(daysWithoutSnacks.count)
            let diff = avgWithSnacks - avgWithoutSnacks

            if diff > 200 {
                insights.append(InsightCard(
                    type: .correlation,
                    icon: "cup.and.saucer.fill",
                    iconColor: "nutriOrange",
                    title: "Snacking Adds Up",
                    message: "Days with snacks average \(Int(avgWithSnacks)) calories vs \(Int(avgWithoutSnacks)) without -- that's \(Int(diff)) extra calories. Choose lower-calorie snacks or plan them into your daily total.",
                    severity: .warning
                ))
            } else if diff < -100 {
                insights.append(InsightCard(
                    type: .correlation,
                    icon: "cup.and.saucer.fill",
                    iconColor: "nutriGreen",
                    title: "Smart Snacking",
                    message: "Days when you include snacks actually have similar or fewer total calories (\(Int(avgWithSnacks)) cal) than non-snack days (\(Int(avgWithoutSnacks)) cal). Healthy snacking can help manage hunger.",
                    severity: .info
                ))
            }
        }

        return insights
    }

    // MARK: - 7. Smart Goal Suggestions

    private static func analyzeGoalSuggestions(daySummaries: [DaySummary], goal: DailyGoal?) -> [InsightCard] {
        guard let goal = goal, daySummaries.count >= 7 else { return [] }

        var insights: [InsightCard] = []
        let dayCount = Double(daySummaries.count)

        let avgCalories = daySummaries.reduce(0.0) { $0 + $1.totalCalories } / dayCount
        let avgProtein = daySummaries.reduce(0.0) { $0 + $1.totalProtein } / dayCount
        let avgCarbs = daySummaries.reduce(0.0) { $0 + $1.totalCarbs } / dayCount
        let avgFat = daySummaries.reduce(0.0) { $0 + $1.totalFat } / dayCount

        // If consistently exceeding calorie goal by >15%, suggest raising it
        if goal.calorieTarget > 0 {
            let calorieRatio = avgCalories / goal.calorieTarget
            if calorieRatio > 1.15 {
                let suggested = Int(avgCalories / 50) * 50 // Round to nearest 50
                insights.append(InsightCard(
                    type: .goalSuggestion,
                    icon: "arrow.up.doc.fill",
                    iconColor: "nutriBlue",
                    title: "Calorie Goal May Be Too Low",
                    message: "You consistently exceed your \(Int(goal.calorieTarget)) calorie target, averaging \(Int(avgCalories)) cal/day. Consider raising your target to \(suggested) for a more realistic goal.",
                    severity: .info
                ))
            } else if calorieRatio < 0.80 {
                let suggested = Int(avgCalories / 50) * 50
                insights.append(InsightCard(
                    type: .goalSuggestion,
                    icon: "arrow.down.doc.fill",
                    iconColor: "nutriBlue",
                    title: "Calorie Goal May Be Too High",
                    message: "You consistently eat below your \(Int(goal.calorieTarget)) calorie target, averaging \(Int(avgCalories)) cal/day. Consider lowering your target to \(suggested) if this feels sustainable.",
                    severity: .info
                ))
            }
        }

        // Macro ratio suggestions based on actual patterns
        if avgCalories > 0 {
            let proteinPct = (avgProtein * 4) / avgCalories * 100
            let carbsPct = (avgCarbs * 4) / avgCalories * 100
            let fatPct = (avgFat * 9) / avgCalories * 100

            // Check if macro goals match actual eating patterns
            let goalTotalMacroCals = (goal.proteinGramsTarget * 4) + (goal.carbsGramsTarget * 4) + (goal.fatGramsTarget * 9)
            if goalTotalMacroCals > 0 {
                let goalProteinPct = (goal.proteinGramsTarget * 4) / goalTotalMacroCals * 100
                let proteinDrift = abs(proteinPct - goalProteinPct)

                if proteinDrift > 15 {
                    let actualGrams = Int(avgProtein)
                    insights.append(InsightCard(
                        type: .goalSuggestion,
                        icon: "slider.horizontal.3",
                        iconColor: "nutriPurple",
                        title: "Adjust Protein Target",
                        message: "Your actual protein intake (\(actualGrams)g, \(Int(proteinPct))% of calories) differs significantly from your target ratio. Consider updating your macro goals to better match your eating style or adjust your diet.",
                        severity: .info
                    ))
                }
            }

            // Suggest balanced macro ratios if extremely skewed
            if carbsPct > 65 {
                insights.append(InsightCard(
                    type: .goalSuggestion,
                    icon: "chart.pie.fill",
                    iconColor: "nutriOrange",
                    title: "Carb-Heavy Diet",
                    message: "About \(Int(carbsPct))% of your calories come from carbs. A more balanced ratio (40-55% carbs, 25-35% fat, 15-25% protein) can support overall health.",
                    severity: .warning
                ))
            }

            if fatPct > 45 {
                insights.append(InsightCard(
                    type: .goalSuggestion,
                    icon: "chart.pie.fill",
                    iconColor: "nutriOrange",
                    title: "Fat-Heavy Diet",
                    message: "About \(Int(fatPct))% of your calories come from fat. Unless you follow a specific low-carb diet, consider balancing your macro ratios.",
                    severity: .warning
                ))
            }
        }

        return insights
    }

    // MARK: - Utility

    /// Simple linear regression slope to detect trend direction.
    /// Returns the slope (change per unit) of the values over their indices.
    private static func calculateTrend(values: [Double]) -> Double {
        let n = Double(values.count)
        guard n >= 3 else { return 0 }

        let indices = (0..<values.count).map { Double($0) }
        let sumX = indices.reduce(0, +)
        let sumY = values.reduce(0, +)
        let sumXY = zip(indices, values).reduce(0.0) { $0 + $1.0 * $1.1 }
        let sumX2 = indices.reduce(0.0) { $0 + $1 * $1 }

        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return 0 }

        return (n * sumXY - sumX * sumY) / denominator
    }
}
