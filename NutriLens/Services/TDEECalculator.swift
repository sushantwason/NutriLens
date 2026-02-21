import Foundation

enum TDEECalculator {
    struct GoalRecommendation {
        let calories: Double
        let proteinGrams: Double
        let carbsGrams: Double
        let fatGrams: Double
    }

    /// Mifflin-St Jeor Basal Metabolic Rate
    /// Male:   10 × weight(kg) + 6.25 × height(cm) - 5 × age + 5
    /// Female: 10 × weight(kg) + 6.25 × height(cm) - 5 × age - 161
    static func bmr(profile: UserProfile) -> Double {
        let base = 10.0 * profile.weightKG + 6.25 * profile.heightCM - 5.0 * Double(profile.age)
        switch profile.biologicalSex {
        case .male:   return base + 5
        case .female: return base - 161
        }
    }

    /// Total Daily Energy Expenditure = BMR × activity multiplier
    static func tdee(profile: UserProfile) -> Double {
        bmr(profile: profile) * profile.activityLevel.tdeeMultiplier
    }

    /// Full macro recommendation based on profile
    /// - Protein: body weight × activity-based multiplier (g)
    /// - Fat: 25% of TDEE calories ÷ 9
    /// - Carbs: remaining calories ÷ 4
    static func recommendGoals(profile: UserProfile) -> GoalRecommendation {
        let totalCalories = tdee(profile: profile)
        let proteinGrams = profile.weightKG * profile.activityLevel.proteinMultiplier
        let proteinCalories = proteinGrams * 4
        let fatCalories = totalCalories * 0.25
        let fatGrams = fatCalories / 9
        let carbsCalories = totalCalories - proteinCalories - fatCalories
        let carbsGrams = max(0, carbsCalories / 4)

        return GoalRecommendation(
            calories: totalCalories.rounded(),
            proteinGrams: proteinGrams.rounded(),
            carbsGrams: carbsGrams.rounded(),
            fatGrams: fatGrams.rounded()
        )
    }

    /// Apply a recommendation to an existing DailyGoal
    static func applyRecommendation(_ recommendation: GoalRecommendation, to goal: DailyGoal) {
        goal.calorieTarget = recommendation.calories
        goal.proteinGramsTarget = recommendation.proteinGrams
        goal.carbsGramsTarget = recommendation.carbsGrams
        goal.fatGramsTarget = recommendation.fatGrams
    }
}
