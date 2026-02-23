import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan: SubscriptionTier = .unlimited
    @State private var isAnnual: Bool = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    billingToggle
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

    // MARK: - Billing Toggle

    private var billingToggle: some View {
        HStack(spacing: 0) {
            billingOption(label: "Monthly", selected: !isAnnual) {
                withAnimation(.easeInOut(duration: 0.2)) { isAnnual = false }
            }
            billingOption(label: "Annual", selected: isAnnual, badge: "Save 40%") {
                withAnimation(.easeInOut(duration: 0.2)) { isAnnual = true }
            }
        }
        .padding(3)
        .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10))
    }

    private func billingOption(label: String, selected: Bool, badge: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.subheadline.weight(selected ? .semibold : .regular))
                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.nutriGreen, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selected ? Color(.systemBackground) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(selected ? .primary : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Plan Cards

    private var planCards: some View {
        HStack(spacing: 12) {
            if isAnnual {
                planCard(
                    tier: .standard,
                    name: "Standard",
                    price: subscriptionManager.standardAnnualProduct?.displayPrice ?? "$34.99",
                    period: "/year",
                    monthlyEquivalent: monthlyEquivalent(for: subscriptionManager.standardAnnualProduct),
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
                    price: subscriptionManager.unlimitedAnnualProduct?.displayPrice ?? "$69.99",
                    period: "/year",
                    monthlyEquivalent: monthlyEquivalent(for: subscriptionManager.unlimitedAnnualProduct),
                    features: [
                        "Unlimited scans",
                        "Meal photos & labels",
                        "Full nutrition tracking"
                    ],
                    tagline: "Best for daily trackers",
                    badge: "BEST VALUE"
                )
            } else {
                planCard(
                    tier: .standard,
                    name: "Standard",
                    price: subscriptionManager.standardProduct?.displayPrice ?? "$4.99",
                    period: "/month",
                    monthlyEquivalent: nil,
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
                    monthlyEquivalent: nil,
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
    }

    private func monthlyEquivalent(for product: Product?) -> String? {
        guard let product else { return nil }
        let monthly = NSDecimalNumber(decimal: product.price / 12)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatStyle.locale
        guard let formatted = formatter.string(from: monthly) else { return nil }
        return "\(formatted)/mo"
    }

    private func planCard(
        tier: SubscriptionTier,
        name: String,
        price: String,
        period: String,
        monthlyEquivalent: String?,
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

                if let monthlyEquivalent {
                    Text(monthlyEquivalent)
                        .font(.caption2)
                        .foregroundStyle(.nutriGreen)
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
                let productID: String
                switch (selectedPlan, isAnnual) {
                case (.standard, false):
                    productID = SubscriptionManager.standardMonthlyProductID
                case (.standard, true):
                    productID = SubscriptionManager.standardAnnualProductID
                case (.unlimited, false):
                    productID = SubscriptionManager.unlimitedMonthlyProductID
                case (.unlimited, true):
                    productID = SubscriptionManager.unlimitedAnnualProductID
                case (.none, _):
                    return
                }
                if let product = subscriptionManager.products.first(where: { $0.id == productID }) {
                    await subscriptionManager.purchase(product: product)
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
            Text("Payment will be charged to your Apple ID account. Subscription auto-renews unless cancelled at least 24 hours before the end of the current period.")
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
