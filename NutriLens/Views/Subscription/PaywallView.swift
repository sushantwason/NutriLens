import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var isAnnual: Bool = true

    private var selectedProduct: Product? {
        isAnnual ? subscriptionManager.annualProduct : subscriptionManager.monthlyProduct
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    featuresSection
                    billingToggle
                    priceCard
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

            Text("Unlimited AI-powered nutrition scanning.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            featureRow("Unlimited meal scans", icon: "camera.fill")
            featureRow("Nutrition labels & barcodes", icon: "doc.text.fill")
            featureRow("Recipe analysis", icon: "book.fill")
            featureRow("AI Coach meal suggestions", icon: "brain.head.profile.fill")
            featureRow("Smart Insights & trends", icon: "chart.line.uptrend.xyaxis")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func featureRow(_ text: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.nutriGreen)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }

    // MARK: - Billing Toggle

    private var billingToggle: some View {
        HStack(spacing: 0) {
            billingOption(label: "Monthly", selected: !isAnnual) {
                withAnimation(.easeInOut(duration: 0.2)) { isAnnual = false }
            }
            billingOption(label: "Annual", selected: isAnnual, badge: "Save 33%") {
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

    // MARK: - Price Card

    private var priceCard: some View {
        VStack(spacing: 8) {
            if let product = selectedProduct {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(product.displayPrice)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text(isAnnual ? "/year" : "/month")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if isAnnual {
                    if let equivalent = monthlyEquivalent(for: product) {
                        Text("Just \(equivalent)/month")
                            .font(.subheadline)
                            .foregroundStyle(.nutriGreen)
                    }
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(isAnnual ? "$39.99" : "$4.99")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text(isAnnual ? "/year" : "/month")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if isAnnual {
                    Text("Just $3.33/month")
                        .font(.subheadline)
                        .foregroundStyle(.nutriGreen)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func monthlyEquivalent(for product: Product) -> String? {
        let monthly = NSDecimalNumber(decimal: product.price / 12)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatStyle.locale
        return formatter.string(from: monthly)
    }

    // MARK: - Subscribe Button

    private var subscribeButton: some View {
        Button {
            Task {
                if let product = selectedProduct {
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
        .disabled(subscriptionManager.isLoading || selectedProduct == nil)
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
            Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. Manage subscriptions and turn off auto-renewal in your Account Settings. Any unused portion of a free trial period will be forfeited upon purchase.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                if let privacyURL = URL(string: "https://nutrilens-api.nutrilens.workers.dev/privacy") {
                    Link("Privacy Policy", destination: privacyURL)
                }
                if let termsURL = URL(string: "https://nutrilens-api.nutrilens.workers.dev/terms") {
                    Link("Terms of Use", destination: termsURL)
                }
            }
            .font(.caption2)
        }
        .padding(.top, 8)
    }
}
