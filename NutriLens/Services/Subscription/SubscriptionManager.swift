import StoreKit
import SwiftUI

enum SubscriptionTier: String {
    case none
    case pro   // $4.99/mo or $39.99/yr, unlimited scans
}

@MainActor @Observable
final class SubscriptionManager {
    // MARK: - State

    var currentTier: SubscriptionTier = .none
    var products: [Product] = []
    var purchaseError: String?
    var isLoading: Bool = false
    var subscriptionExpirationDate: Date?

    /// True for any active subscription
    var isProUser: Bool {
        currentTier == .pro
    }

    // MARK: - Product IDs

    static let proMonthlyProductID = "com.nutrilensapp.app.pro.monthly"
    static let proAnnualProductID = "com.nutrilensapp.app.pro.annual"

    // Legacy product IDs for migration
    static let legacyProMonthlyProductID = "com.nutrilens.app.pro.monthly"
    static let legacyStandardMonthlyProductID = "com.nutrilensapp.app.standard.monthly"
    static let legacyUnlimitedMonthlyProductID = "com.nutrilensapp.app.unlimited.monthly"
    static let legacyStandardAnnualProductID = "com.nutrilensapp.app.standard.annual"
    static let legacyUnlimitedAnnualProductID = "com.nutrilensapp.app.unlimited.annual"

    private static var allProductIDs: Set<String> {
        [proMonthlyProductID, proAnnualProductID,
         legacyProMonthlyProductID, legacyStandardMonthlyProductID,
         legacyUnlimitedMonthlyProductID, legacyStandardAnnualProductID,
         legacyUnlimitedAnnualProductID]
    }

    // MARK: - Private

    private nonisolated(unsafe) var transactionListener: Task<Void, Never>?

    init() {
        // Owner always gets pro
        if OwnerBypass.isOwnerDevice {
            currentTier = .pro
            return
        }

        // Listen for transaction updates (renewals, revocations, etc.)
        transactionListener = listenForTransactions()

        // Check current entitlement status
        Task { await updateSubscriptionStatus() }
    }

    nonisolated deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        purchaseError = nil
        do {
            let storeProducts = try await Product.products(for: Self.allProductIDs)
            // Only show current products (not legacy), sorted by price
            products = storeProducts
                .filter { $0.id == Self.proMonthlyProductID || $0.id == Self.proAnnualProductID }
                .sorted { $0.price < $1.price }

            if products.isEmpty {
                purchaseError = "Subscriptions are temporarily unavailable. Please try again later."
            }
        } catch {
            purchaseError = "Failed to load products: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Purchase

    func purchase(product: Product) async {
        isLoading = true
        purchaseError = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await updateSubscriptionStatus()
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Restore

    func restorePurchases() async {
        isLoading = true
        try? await AppStore.sync()
        await updateSubscriptionStatus()
        isLoading = false
    }

    // MARK: - Subscription Status

    func updateSubscriptionStatus() async {
        if OwnerBypass.isOwnerDevice {
            currentTier = .pro
            return
        }

        var detectedTier: SubscriptionTier = .none
        var latestExpiration: Date?

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                switch transaction.productID {
                case Self.proMonthlyProductID, Self.proAnnualProductID,
                     Self.legacyProMonthlyProductID,
                     Self.legacyStandardMonthlyProductID, Self.legacyUnlimitedMonthlyProductID,
                     Self.legacyStandardAnnualProductID, Self.legacyUnlimitedAnnualProductID:
                    // All legacy tiers migrate to pro
                    detectedTier = .pro
                    latestExpiration = transaction.expirationDate
                default:
                    break
                }
            }
        }

        currentTier = detectedTier
        subscriptionExpirationDate = latestExpiration
    }

    // MARK: - Helpers

    var monthlyProduct: Product? {
        products.first { $0.id == Self.proMonthlyProductID }
    }

    var annualProduct: Product? {
        products.first { $0.id == Self.proAnnualProductID }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? self?.checkVerified(result) {
                    await transaction.finish()
                    await self?.updateSubscriptionStatus()
                }
            }
        }
    }

    // MARK: - Verification

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}
