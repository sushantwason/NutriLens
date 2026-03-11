import TelemetryDeck

enum AnalyticsService {

    // MARK: - Configuration

    static func configure() {
        let config = TelemetryDeck.Config(appID: AppSecrets.telemetryDeckAppID)
        #if DEBUG
        config.testMode = true
        #endif
        TelemetryDeck.initialize(config: config)
    }

    // MARK: - Tracking

    static func track(_ event: Event, parameters: [String: String] = [:]) {
        TelemetryDeck.signal(event.rawValue, parameters: parameters)
    }

    // MARK: - Event Catalog

    enum Event: String {
        // App lifecycle
        case appOpened = "app.opened"
        case appBackgrounded = "app.backgrounded"

        // Onboarding funnel
        case onboardingStepViewed = "onboarding.stepViewed"
        case onboardingStepCompleted = "onboarding.stepCompleted"
        case onboardingStepSkipped = "onboarding.stepSkipped"
        case onboardingCompleted = "onboarding.completed"

        // Scan / Analysis
        case scanInitiated = "scan.initiated"
        case scanSuccess = "scan.success"
        case scanFailed = "scan.failed"
        case scanGatedByPaywall = "scan.gatedByPaywall"

        // Meals
        case mealSaved = "meal.saved"
        case mealDeleted = "meal.deleted"
        case mealDuplicated = "meal.duplicated"
        case mealFavorited = "meal.favorited"

        // Food search
        case foodSearchOpened = "foodSearch.opened"
        case foodSearchCompleted = "foodSearch.completed"

        // Subscription funnel
        case paywallShown = "paywall.shown"
        case purchaseInitiated = "purchase.initiated"
        case purchaseCompleted = "purchase.completed"
        case purchaseFailed = "purchase.failed"
        case purchaseRestored = "purchase.restored"

        // Engagement
        case tabChanged = "tab.changed"
        case coachInsightViewed = "coach.insightViewed"
        case smartInsightsOpened = "insights.opened"
        case achievementsViewed = "achievements.viewed"
        case widgetUpsellShown = "widgetUpsell.shown"
        case widgetUpsellDismissed = "widgetUpsell.dismissed"

        // Settings
        case goalsEdited = "settings.goalsEdited"
        case feedbackSent = "feedback.sent"
        case appStoreReviewPrompted = "settings.appStoreReview"
        case referralShared = "settings.referralShared"
    }
}
