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
        .gesture(
            DragGesture(minimumDistance: 50, coordinateSpace: .global)
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = value.translation.height
                    // Only trigger for predominantly horizontal swipes
                    guard abs(horizontal) > abs(vertical) else { return }
                    withAnimation {
                        if horizontal < 0 {
                            // Swipe left → next tab
                            selectedTab = min(selectedTab + 1, tabCount - 1)
                        } else {
                            // Swipe right → previous tab
                            selectedTab = max(selectedTab - 1, 0)
                        }
                    }
                }
        )
        .onChange(of: selectedTab) { _, _ in
            HapticService.tabChanged()
        }
    }
}

#Preview {
    MainTabView()
}
