import SwiftUI

struct ContentView: View {
    @AppStorage("nutrilens.onboarding.completed") private var onboardingCompleted = false
    @AppStorage("nutrilens.appearance.mode") private var appearanceMode: String = AppearanceMode.system.rawValue

    private var selectedAppearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceMode) ?? .system
    }

    var body: some View {
        Group {
            if onboardingCompleted {
                MainTabView()
            } else {
                OnboardingView {
                    withAnimation {
                        onboardingCompleted = true
                    }
                }
            }
        }
        .preferredColorScheme(selectedAppearance.colorScheme)
    }
}

#Preview {
    ContentView()
}
