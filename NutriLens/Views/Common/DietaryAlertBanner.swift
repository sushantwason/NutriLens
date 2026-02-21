import SwiftUI

struct DietaryAlertBanner: View {
    let alerts: [DietaryAlertChecker.Alert]

    @State private var isExpanded = false

    var body: some View {
        if !alerts.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.white)
                    Text("Dietary Alerts (\(alerts.count))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    if alerts.count > 2 {
                        Button {
                            withAnimation { isExpanded.toggle() }
                        } label: {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }

                // Alert rows
                let displayedAlerts = (isExpanded || alerts.count <= 2) ? alerts : Array(alerts.prefix(2))
                ForEach(displayedAlerts) { alert in
                    HStack(spacing: 6) {
                        Image(systemName: alert.restriction.icon)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(alert.restriction.displayName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(alert.reason)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }

                if !isExpanded && alerts.count > 2 {
                    Text("+\(alerts.count - 2) more")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(12)
            .background(.nutriOrange.gradient, in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
