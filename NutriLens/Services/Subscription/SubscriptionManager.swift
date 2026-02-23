import StoreKit
import SwiftUI

enum SubscriptionTier: String {
    case none
    case standard   // $4.99/mo, 100 scans
    case unlimited  // $9.99/mo, unlimited scans
}

@MainActor @Observable
final class SubscriptionManager {
    // MARK: - State

    var currentTier: SubscriptionTier = .none
    var products: [Product] = []
    var purchaseError: String?
    var isLoading: Bool = false
    var subscriptionExpirationDate: Date?

    /// Backward-compatible: true for any active subscription
    var isProUser: Bool {
        currentTier != .none
    }

    // MARK: - Product IDs

    static let standardMonthlyProductID = "com.nutrilensapp.app.standard.monthly"
    static let unlimitedMonthlyProductID = "com.nutrilensapp.app.unlimited.monthly"
    static let standardAnnualProductID = "com.nutrilensapp.app.standard.annual"
    static let unlimitedAnnualProductID = "com.nutrilensapp.app.unlimited.annual"

    // Legacy product ID for migration
    static let legacyProMonthlyProductID = "com.nutrilens.app.pro.monthly"

    private static var allProductIDs: Set<String> {
        [standardMonthlyProductID, unlimitedMonthlyProductID,
         standardAnnualProductID, unlimitedAnnualProductID,
         legacyProMonthlyProductID]
    }

    // MARK: - Private

    private nonisolated(unsafe) var transactionListener: Task<Void, Never>?

    init() {
        // Owner always gets unlimited
        if OwnerBypass.isOwnerDevice {
            currentTier = .unlimited
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
        do {
            let storeProducts = try await Product.products(for: Self.allProductIDs)
            // Sort: standard first, then unlimited
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            purchaseError = "Failed to load products: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Purchase

    func purchaseStandard() async {
        await purchase(productID: Self.standardMonthlyProductID)
    }

    func purchaseUnlimited() async {
        await purchase(productID: Self.unlimitedMonthlyProductID)
    }

    private func purchase(productID: String) async {
        guard let product = products.first(where: { $0.id == productID }) else {
            purchaseError = "Product not available"
            return
        }

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
            currentTier = .unlimited
            return
        }

        var detectedTier: SubscriptionTier = .none
        var latestExpiration: Date?

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                switch transaction.productID {
                case Self.unlimitedMonthlyProductID, Self.unlimitedAnnualProductID:
                    detectedTier = .unlimited
                    latestExpiration = transaction.expirationDate
                case Self.standardMonthlyProductID, Self.standardAnnualProductID:
                    // Only set standard if we haven't found unlimited
                    if detectedTier != .unlimited {
                        detectedTier = .standard
                        latestExpiration = transaction.expirationDate
                    }
                case Self.legacyProMonthlyProductID:
                    // Legacy pro users get unlimited
                    detectedTier = .unlimited
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

    var standardProduct: Product? {
        products.first { $0.id == Self.standardMonthlyProductID }
    }

    var unlimitedProduct: Product? {
        products.first { $0.id == Self.unlimitedMonthlyProductID }
    }

    var standardAnnualProduct: Product? {
        products.first { $0.id == Self.standardAnnualProductID }
    }

    var unlimitedAnnualProduct: Product? {
        products.first { $0.id == Self.unlimitedAnnualProductID }
    }

    func purchase(product: Product) async {
        await purchase(productID: product.id)
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
