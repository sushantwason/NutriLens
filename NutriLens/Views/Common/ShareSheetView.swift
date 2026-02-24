import SwiftUI

/// Present a UIActivityViewController directly on the topmost view controller,
/// avoiding the double-sheet issue when wrapped in a SwiftUI `.sheet`.
enum ShareSheet {
    @MainActor
    static func present(items: [Any]) {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        topVC.present(activityVC, animated: true)
    }
}
