import WidgetKit
import SwiftUI

@main
struct NutriLensWidgetBundle: WidgetBundle {
    var body: some Widget {
        NutriLensWidget()
        NutriLensLockScreenWidget()
    }
}
