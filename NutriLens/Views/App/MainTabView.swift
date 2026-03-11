import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    private let tabCount = 3

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.pie.fill")
                }
                .tag(0)

            MealHistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
                .tag(1)

            NutritionTrackingView()
                .tabItem {
                    Label("Tracking", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(2)
        }
        .tint(.nutriGreen)
        .onChange(of: selectedTab) { _, newTab in
            HapticService.tabChanged()
            let tabNames = ["dashboard", "history", "tracking"]
            if newTab < tabNames.count {
                AnalyticsService.track(.tabChanged, parameters: ["tab": tabNames[newTab]])
            }
        }
    }
}

#Preview {
    MainTabView()
}
