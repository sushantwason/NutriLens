import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query(filter: #Predicate<DailyGoal> { $0.isActive == true }) private var activeGoals: [DailyGoal]
    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(TrialManager.self) private var trialManager
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(ScanCounter.self) private var scanCounter

    @AppStorage("nutrilens.appearance.mode") private var appearanceMode: String = AppearanceMode.system.rawValue
    @State private var showPaywall = false

    private var currentGoal: DailyGoal {
        if let goal = activeGoals.first {
            return goal
        }
        let newGoal = DailyGoal()
        modelContext.insert(newGoal)
        try? modelContext.save()
        return newGoal
    }

    private var currentProfile: UserProfile {
        if let profile = profiles.first {
            return profile
        }
        let newProfile = UserProfile()
        modelContext.insert(newProfile)
        try? modelContext.save()
        return newProfile
    }

    var body: some View {
        NavigationStack {
            List {
                subscriptionSection
                appearanceSection
                dailyGoalsSection
                profileSection
                weightSection
                exportSection
                healthKitSection
                aboutSection
                if OwnerBypass.isOwnerDevice {
                    developerSection
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
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

            // Scan count for Standard tier
            if subscriptionManager.currentTier == .standard && !OwnerBypass.isOwnerDevice {
                HStack {
                    Image(systemName: "camera.fill")
                        .foregroundStyle(.secondary)
                    Text("\(scanCounter.monthlyCount) / \(ScanCounter.standardMonthlyLimit) scans used this month")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await subscriptionManager.loadProducts() }
                    showPaywall = true
                } label: {
                    Label("Upgrade to Unlimited", systemImage: "sparkles")
                }
            }

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
        if OwnerBypass.isOwnerDevice { return "NutriLens Pro" }
        switch subscriptionManager.currentTier {
        case .unlimited: return "NutriLens Unlimited"
        case .standard: return "NutriLens Standard"
        case .none: break
        }
        if trialManager.isTrialActive { return "Free Trial" }
        return "Trial Expired"
    }

    private var statusBadge: String {
        if OwnerBypass.isOwnerDevice { return "Owner" }
        switch subscriptionManager.currentTier {
        case .unlimited: return "Unlimited"
        case .standard: return "Standard"
        case .none: break
        }
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
            NavigationLink {
                GoalEditorView(goal: currentGoal)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    goalRow("Calories", value: currentGoal.calorieTarget, unit: "kcal", color: .calorieColor)
                    goalRow("Protein", value: currentGoal.proteinGramsTarget, unit: "g", color: .proteinColor)
                    goalRow("Carbs", value: currentGoal.carbsGramsTarget, unit: "g", color: .carbsColor)
                    goalRow("Fat", value: currentGoal.fatGramsTarget, unit: "g", color: .fatColor)
                }
            }
        }
    }

    private func goalRow(_ name: String, value: Double, unit: String, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(name)
                .font(.subheadline)
            Spacer()
            Text("\(value.oneDecimalString) \(unit)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section("Profile") {
            NavigationLink {
                ProfileEditorView(profile: currentProfile)
            } label: {
                HStack {
                    Label("Body Profile", systemImage: "person.fill")
                    Spacer()
                    if let profile = profiles.first {
                        Text("BMI \(profile.bmi, specifier: "%.1f")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Weight

    private var weightSection: some View {
        Section("Weight") {
            NavigationLink {
                WeightLogView()
            } label: {
                Label("Weight Log", systemImage: "scalemass.fill")
            }
        }
    }

    // MARK: - Export

    private var exportSection: some View {
        Section("Data") {
            NavigationLink {
                WeeklyReportView()
            } label: {
                Label("Weekly Report", systemImage: "chart.bar.doc.horizontal")
            }

            NavigationLink {
                ExportView()
            } label: {
                Label("Export Data", systemImage: "square.and.arrow.up")
            }
        }
    }

    // MARK: - HealthKit

    private var healthKitSection: some View {
        Section("Apple Health") {
            NavigationLink {
                HealthKitSettingsView()
            } label: {
                HStack {
                    Label("HealthKit Sync", systemImage: "heart.fill")
                    Spacer()
                    Text(healthKitManager.isAuthorized ? "Connected" : "Off")
                        .font(.caption)
                        .foregroundStyle(healthKitManager.isAuthorized ? .nutriGreen : .secondary)
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "1.0.0")
            LabeledContent("AI Model", value: "Claude Sonnet")
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
        .environment(HealthKitManager())
        .environment(ScanCounter())
}
