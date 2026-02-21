import SwiftUI

struct HealthKitSettingsView: View {
    @Environment(HealthKitManager.self) private var healthKitManager

    var body: some View {
        List {
            // Status
            Section {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.nutriRed)
                    Text("Apple Health")
                        .font(.headline)
                    Spacer()
                    Text(healthKitManager.isAuthorized ? "Connected" : "Not Connected")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(healthKitManager.isAuthorized ? .nutriGreen : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            (healthKitManager.isAuthorized ? Color.nutriGreen : Color.secondary).opacity(0.15),
                            in: Capsule()
                        )
                }
            }

            if !healthKitManager.isAvailable {
                // Simulator / unsupported device
                Section {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.nutriOrange)
                        Text("HealthKit is not available on this device.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                // Authorization
                Section("Connection") {
                    if healthKitManager.isAuthorized {
                        Label("Connected to Apple Health", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.nutriGreen)
                    } else {
                        Button {
                            Task {
                                _ = await healthKitManager.requestAuthorization()
                            }
                        } label: {
                            Label("Connect to Apple Health", systemImage: "heart.circle.fill")
                        }
                    }
                }

                // What's synced
                Section("What NutriLens Syncs") {
                    VStack(alignment: .leading, spacing: 8) {
                        syncRow(icon: "arrow.down.circle", label: "Reads", items: "Body Weight")
                        syncRow(icon: "arrow.up.circle", label: "Writes", items: "Calories, Protein, Carbs, Fat, Water")
                    }
                }

                // Info
                Section {
                    Text("NutriLens automatically syncs your meal nutrition and water intake to Apple Health when you log them. Weight data can be imported from Health into your weight log.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("HealthKit Sync")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func syncRow(icon: String, label: String, items: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.nutriBlue)
                .font(.caption)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.semibold))
                Text(items)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
