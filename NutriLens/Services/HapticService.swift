import UIKit

enum HapticService {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    // MARK: - Semantic Haptics

    static func mealSaved() { notification(.success) }
    static func mealDeleted() { notification(.warning) }
    static func waterAdded() { impact(.light) }
    static func goalReached() { notification(.success) }
    static func tabChanged() { selection() }
    static func buttonTap() { impact(.light) }
    static func errorOccurred() { notification(.error) }
    static func scanStarted() { impact(.medium) }
}
