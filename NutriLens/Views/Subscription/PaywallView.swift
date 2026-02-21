import SwiftUI

struct PaywallView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan: SubscriptionTier = .unlimited

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    planCards
                    subscribeButton
                    restoreAndError
                    footerSection
                }
                .padding()
            }
            .navigationTitle("MealSight Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                if subscriptionManager.products.isEmpty {
                    await subscriptionManager.loadProducts()
                }
            }
            .onChange(of: subscriptionManager.isProUser) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.nutriGreen)

            Text("Unlock MealSight Pro")
                .font(.title2.bold())

            Text("Choose a plan that fits your tracking needs.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    // MARK: - Plan Cards

    private var planCards: some View {
        HStack(spacing: 12) {
            planCard(
                tier: .standard,
                name: "Standard",
                price: subscriptionManager.standardProduct?.displayPrice ?? "$4.99",
                period: "/month",
                features: [
                    "100 scans per month",
                    "Meal photos & labels",
                    "Full nutrition tracking"
                ],
                tagline: "Perfect for casual trackers",
                badge: nil
            )

            planCard(
                tier: .unlimited,
                name: "Unlimited",
                price: subscriptionManager.unlimitedProduct?.displayPrice ?? "$9.99",
                period: "/month",
                features: [
                    "Unlimited scans",
                    "Meal photos & labels",
                    "Full nutrition tracking"
                ],
                tagline: "Best for daily trackers",
                badge: "BEST VALUE"
            )
        }
    }

    private func planCard(
        tier: SubscriptionTier,
        name: String,
        price: String,
        period: String,
        features: [String],
        tagline: String,
        badge: String?
    ) -> some View {
        let isSelected = selectedPlan == tier

        return Button {
            selectedPlan = tier
            HapticService.buttonTap()
        } label: {
            VStack(spacing: 12) {
                // Badge
                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.nutriGreen, in: Capsule())
                } else {
                    // Invisible spacer to keep cards aligned
                    Text(" ")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .opacity(0)
                }

                Text(name)
                    .font(.headline)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(period)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(features, id: \.self) { feature in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.nutriGreen)
                            Text(feature)
                                .font(.caption)
                        }
                    }
                }

                Spacer(minLength: 0)

                Text(tagline)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.nutriGreen : Color.clear, lineWidth: 2)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subscribe Button

    private var subscribeButton: some View {
        Button {
            Task {
                switch selectedPlan {
                case .standard:
                    await subscriptionManager.purchaseStandard()
                case .unlimited:
                    await subscriptionManager.purchaseUnlimited()
                case .none:
                    break
                }
            }
        } label: {
            Group {
                if subscriptionManager.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Subscribe Now")
                }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.nutriGreen, in: RoundedRectangle(cornerRadius: 14))
        }
        .disabled(subscriptionManager.isLoading || subscriptionManager.products.isEmpty)
    }

    // MARK: - Restore & Error

    private var restoreAndError: some View {
        VStack(spacing: 8) {
            Button {
                Task { await subscriptionManager.restorePurchases() }
            } label: {
                Text("Restore Purchases")
                    .font(.subheadline)
            }

            if let error = subscriptionManager.purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 8) {
            Text("Payment will be charged to your Apple ID account. Subscription auto-renews monthly unless cancelled at least 24 hours before the end of the current period.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                if let privacyURL = URL(string: "https://nutrilens.app/privacy") {
                    Link("Privacy Policy", destination: privacyURL)
                }
                if let termsURL = URL(string: "https://nutrilens.app/terms") {
                    Link("Terms of Use", destination: termsURL)
                }
            }
            .font(.caption2)
        }
        .padding(.top, 8)
    }
}
