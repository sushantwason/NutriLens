import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var currentPage = 0

    // Profile state
    @State private var heightCM: Double = 170
    @State private var weightKG: Double = 70
    @State private var age: Double = 30
    @State private var biologicalSex: BiologicalSex = .male
    @State private var activityLevel: ActivityLevel = .moderatelyActive
    @State private var profileCompleted = false

    // Dietary state
    @State private var dietaryRestrictions: Set<DietaryRestriction> = []

    // Goal state
    @State private var calorieTarget: Double = 2000
    @State private var proteinTarget: Double = 150
    @State private var carbsTarget: Double = 250
    @State private var fatTarget: Double = 65
    @State private var sugarTarget: Double = 50

    let onComplete: () -> Void

    var body: some View {
        TabView(selection: $currentPage) {
            OnboardingWelcomeStep {
                AnalyticsService.track(.onboardingStepCompleted, parameters: ["step": "welcome"])
                withAnimation { currentPage = 1 }
            }
            .tag(0)

            OnboardingProfileStep(
                heightCM: $heightCM,
                weightKG: $weightKG,
                age: $age,
                biologicalSex: $biologicalSex,
                activityLevel: $activityLevel,
                onNext: {
                    AnalyticsService.track(.onboardingStepCompleted, parameters: ["step": "profile"])
                    applyProfileRecommendation()
                    profileCompleted = true
                    withAnimation { currentPage = 2 }
                },
                onSkip: {
                    AnalyticsService.track(.onboardingStepSkipped, parameters: ["step": "profile"])
                    withAnimation { currentPage = 2 }
                }
            )
            .tag(1)

            OnboardingDietaryStep(
                dietaryRestrictions: $dietaryRestrictions,
                onNext: {
                    AnalyticsService.track(.onboardingStepCompleted, parameters: ["step": "dietary"])
                    withAnimation { currentPage = 3 }
                },
                onSkip: {
                    AnalyticsService.track(.onboardingStepSkipped, parameters: ["step": "dietary"])
                    withAnimation { currentPage = 3 }
                }
            )
            .tag(2)

            OnboardingGoalStep(
                calorieTarget: $calorieTarget,
                proteinTarget: $proteinTarget,
                carbsTarget: $carbsTarget,
                fatTarget: $fatTarget,
                sugarTarget: $sugarTarget
            ) {
                AnalyticsService.track(.onboardingStepCompleted, parameters: ["step": "goal"])
                withAnimation { currentPage = 4 }
            }
            .tag(3)

            OnboardingReadyStep {
                AnalyticsService.track(.onboardingCompleted)
                saveGoals()
                onComplete()
            }
            .tag(4)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .interactiveDismissDisabled()
        .onAppear {
            AnalyticsService.track(.onboardingStepViewed, parameters: ["step": "welcome"])
        }
        .onChange(of: currentPage) { _, newPage in
            let stepNames = ["welcome", "profile", "dietary", "goal", "ready"]
            if newPage < stepNames.count {
                AnalyticsService.track(.onboardingStepViewed, parameters: ["step": stepNames[newPage]])
            }
        }
    }

    private func applyProfileRecommendation() {
        let profile = UserProfile(
            heightCM: heightCM,
            weightKG: weightKG,
            age: Int(age),
            biologicalSex: biologicalSex,
            activityLevel: activityLevel
        )
        let rec = TDEECalculator.recommendGoals(profile: profile)
        calorieTarget = rec.calories
        proteinTarget = rec.proteinGrams
        carbsTarget = rec.carbsGrams
        fatTarget = rec.fatGrams
    }

    private func saveGoals() {
        let goal = DailyGoal(
            calorieTarget: calorieTarget,
            proteinGramsTarget: proteinTarget,
            carbsGramsTarget: carbsTarget,
            fatGramsTarget: fatTarget,
            sugarGramsTarget: sugarTarget
        )
        modelContext.insert(goal)

        if profileCompleted {
            let profile = UserProfile(
                heightCM: heightCM,
                weightKG: weightKG,
                age: Int(age),
                biologicalSex: biologicalSex,
                activityLevel: activityLevel
            )
            profile.dietaryRestrictions = Array(dietaryRestrictions)
            modelContext.insert(profile)
        }

        try? modelContext.save()
    }
}
