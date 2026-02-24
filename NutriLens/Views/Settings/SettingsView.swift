import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query(filter: #Predicate<DailyGoal> { $0.isActive == true }) private var activeGoals: [DailyGoal]
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(TrialManager.self) private var trialManager
    @Environment(MealReminderManager.self) private var mealReminderManager

    @AppStorage("nutrilens.appearance.mode") private var appearanceMode: String = AppearanceMode.system.rawValue
    @State private var showPaywall = false
    @State private var localGoal: DailyGoal?
    @State private var localProfile: UserProfile?
    @State private var didSetupDefaults = false

    private var currentGoal: DailyGoal {
        localGoal ?? activeGoals.first ?? DailyGoal()
    }

    private var currentProfile: UserProfile {
        localProfile ?? profiles.first ?? UserProfile()
    }

    var body: some View {
        List {
            subscriptionSection
            appearanceSection
            dailyGoalsSection
            profileSection
            dietaryRestrictionsSection
            mealRemindersSection
            widgetsSection
            achievementsSection
            referralsSection
            feedbackSection
            helpSection
            aboutSection
            if OwnerBypass.isOwnerDevice {
                developerSection
            }
        }
        .navigationTitle("Settings")
        .task {
            guard !didSetupDefaults else { return }
            didSetupDefaults = true
            // Create default goal/profile once, outside the render cycle
            if activeGoals.isEmpty && localGoal == nil {
                let newGoal = DailyGoal()
                modelContext.insert(newGoal)
                try? modelContext.save()
                localGoal = newGoal
            }
            if profiles.isEmpty && localProfile == nil {
                let newProfile = UserProfile()
                modelContext.insert(newProfile)
                try? modelContext.save()
                localProfile = newProfile
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Subscription

    private var subscriptionSection: some View {
        Section("Subscription") {
            // Status row
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                Text(statusLabel)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(statusBadge)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor.opacity(0.15), in: Capsule())
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Subscription status: \(statusLabel), \(statusBadge)")

            // Trial countdown
            if !subscriptionManager.isProUser && !OwnerBypass.isOwnerDevice {
                if trialManager.isTrialActive {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.secondary)
                        let days = trialManager.trialDaysRemaining
                        Text("Trial ends in \(days) day\(days == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }

                Button {
                    Task { await subscriptionManager.loadProducts() }
                    showPaywall = true
                } label: {
                    Label("Upgrade to Pro", systemImage: "sparkles")
                }
            }

            // Renewal info for Pro users
            if subscriptionManager.isProUser,
               !OwnerBypass.isOwnerDevice,
               let expiration = subscriptionManager.subscriptionExpirationDate {
                LabeledContent("Renews", value: expiration.mediumDateString)
            }

            // Manage subscription link
            if subscriptionManager.isProUser && !OwnerBypass.isOwnerDevice {
                Button {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Manage Subscription", systemImage: "arrow.up.forward.app")
                }
            }
        }
    }

    private var statusIcon: String {
        if OwnerBypass.isOwnerDevice { return "crown.fill" }
        if subscriptionManager.isProUser { return "crown.fill" }
        if trialManager.isTrialActive { return "clock.fill" }
        return "lock.fill"
    }

    private var statusColor: Color {
        if OwnerBypass.isOwnerDevice || subscriptionManager.isProUser { return .nutriGreen }
        if trialManager.isTrialActive { return .nutriOrange }
        return .nutriRed
    }

    private var statusLabel: String {
        if OwnerBypass.isOwnerDevice { return "MealSight Pro" }
        if subscriptionManager.isProUser { return "MealSight Pro" }
        if trialManager.isTrialActive { return "Free Trial" }
        return "Trial Expired"
    }

    private var statusBadge: String {
        if OwnerBypass.isOwnerDevice { return "Owner" }
        if subscriptionManager.isProUser { return "Pro" }
        if trialManager.isTrialActive { return "Trial" }
        return "Expired"
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $appearanceMode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.icon)
                        .tag(mode.rawValue)
                }
            }
            .pickerStyle(.navigationLink)
        }
    }

    // MARK: - Daily Goals

    private var dailyGoalsSection: some View {
        Section("Daily Goals") {
            if let goal = activeGoals.first ?? localGoal {
                NavigationLink {
                    GoalEditorView(goal: goal)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        goalRow("Calories", value: goal.calorieTarget, unit: "kcal", color: .calorieColor)
                        goalRow("Protein", value: goal.proteinGramsTarget, unit: "g", color: .proteinColor)
                        goalRow("Carbs", value: goal.carbsGramsTarget, unit: "g", color: .carbsColor)
                        goalRow("Fat", value: goal.fatGramsTarget, unit: "g", color: .fatColor)
                    }
                }
            } else {
                ProgressView()
            }
        }
    }

    private func goalRow(_ name: String, value: Double, unit: String, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(name)
                .font(.subheadline)
            Spacer()
            Text("\(value.oneDecimalString) \(unit)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name): \(value.oneDecimalString) \(unit)")
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section("Profile") {
            if let profile = profiles.first ?? localProfile {
                NavigationLink {
                    ProfileEditorView(profile: profile)
                } label: {
                    HStack {
                        Label("Body Profile", systemImage: "person.fill")
                        Spacer()
                        Text("BMI \(profile.bmi, specifier: "%.1f")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityHint("Edit your body profile")
            } else {
                ProgressView()
            }
        }
    }

    // MARK: - Dietary Restrictions

    private var dietaryRestrictionsSection: some View {
        Section("Dietary Restrictions") {
            NavigationLink {
                if let profile = profiles.first ?? localProfile {
                    DietaryRestrictionsEditorView(profile: profile)
                }
            } label: {
                HStack {
                    Label("Restrictions", systemImage: "leaf.fill")
                    Spacer()
                    Text(restrictionsSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint("Edit your dietary restrictions for alerts and AI suggestions")
        }
    }

    private var restrictionsSummary: String {
        let restrictions = (profiles.first ?? localProfile)?.dietaryRestrictions ?? []
        return restrictions.isEmpty ? "None" : restrictions.map(\.displayName).joined(separator: ", ")
    }

    // MARK: - Meal Reminders

    private var mealRemindersSection: some View {
        Section("Notifications") {
            NavigationLink {
                MealReminderSettingsView()
            } label: {
                HStack {
                    Label("Meal Reminders", systemImage: "bell.badge.fill")
                    Spacer()
                    Text(mealReminderManager.isEnabled ? "On" : "Off")
                        .font(.caption)
                        .foregroundStyle(mealReminderManager.isEnabled ? .nutriGreen : .secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(mealReminderManager.isEnabled ? "On" : "Off")
            .accessibilityHint("Configure meal reminder notifications")
        }
    }

    // MARK: - Widgets

    private var widgetsSection: some View {
        Section("Widgets") {
            VStack(alignment: .leading, spacing: 8) {
                Label("Home & Lock Screen", systemImage: "square.grid.2x2.fill")
                    .font(.subheadline.weight(.medium))

                Text("Add MealSight widgets to see your daily calories and macros at a glance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.caption2)
                        .foregroundStyle(.nutriGreen)
                    Text("Long-press home screen \u{2192} \u{FF0B} \u{2192} search MealSight")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(6)
                .background(Color.nutriGreen.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Widgets: Add MealSight widgets to your home or lock screen")
            .accessibilityHint("Long-press your home screen, tap plus, and search MealSight")
        }
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        Section("Achievements") {
            NavigationLink {
                AchievementsView()
            } label: {
                Label("Badges & Milestones", systemImage: "trophy.fill")
            }
        }
    }

    // MARK: - Referrals

    private var referralsSection: some View {
        Section("Referrals") {
            Button {
                shareReferralLink()
            } label: {
                Label("Refer a Friend", systemImage: "person.2.fill")
            }
            .accessibilityHint("Opens share sheet with a referral link")
        }
    }

    private func shareReferralLink() {
        let shareText = "Check out MealSight — it scans your meals and instantly tells you the calories, protein, carbs, and fat! https://apps.apple.com/app/id6745208953"
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            // Find the topmost presented controller to avoid presentation conflicts
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(activityVC, animated: true)
        }
    }

    // MARK: - Feedback

    private var feedbackSection: some View {
        Section("Feedback") {
            NavigationLink {
                FeedbackView()
            } label: {
                Label("Send Feedback", systemImage: "bubble.left.and.bubble.right.fill")
            }

            Button {
                requestAppStoreReview()
            } label: {
                Label("Rate on App Store", systemImage: "star.fill")
            }
            .accessibilityHint("Opens the App Store to leave a review")
        }
    }

    private func requestAppStoreReview() {
        if let url = URL(string: "https://apps.apple.com/app/id6745208953?action=write-review") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Help & Onboarding

    private var helpSection: some View {
        Section("Help & Onboarding") {
            NavigationLink {
                AppTutorialView()
            } label: {
                Label("App Tutorial", systemImage: "book.fill")
            }

            Button {
                UserDefaults.standard.set(false, forKey: "nutrilens.onboarding.completed")
                HapticService.notification(.success)
            } label: {
                Label("Restart Onboarding", systemImage: "arrow.counterclockwise")
            }
            .accessibilityHint("Resets and shows the onboarding tutorial again")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "1.0 (6)")
            LabeledContent("AI Model", value: "Claude Haiku")

            NavigationLink {
                DisclaimersView()
            } label: {
                Label("Disclaimers & Legal", systemImage: "doc.text")
            }
        }
    }

    // MARK: - Developer

    private var developerSection: some View {
        Section("Developer") {
            Button("Reset Onboarding") {
                UserDefaults.standard.set(false, forKey: "nutrilens.onboarding.completed")
                HapticService.notification(.success)
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [DailyGoal.self, UserProfile.self, WeightEntry.self], inMemory: true)
        .environment(SubscriptionManager())
        .environment(TrialManager())
        .environment(MealReminderManager())
}
