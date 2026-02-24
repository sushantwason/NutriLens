import SwiftUI

extension ShapeStyle where Self == Color {
    static var nutriGreen: Color { Color(red: 0.35, green: 0.78, blue: 0.48) }
    static var nutriBlue: Color { Color(red: 0.30, green: 0.56, blue: 0.92) }
    static var nutriOrange: Color { Color(red: 0.96, green: 0.65, blue: 0.14) }
    static var nutriRed: Color { Color(red: 0.92, green: 0.34, blue: 0.34) }
    static var nutriPurple: Color { Color(red: 0.62, green: 0.42, blue: 0.87) }

    static var calorieColor: Color { .nutriOrange }
    static var proteinColor: Color { .nutriBlue }
    static var carbsColor: Color { .nutriGreen }
    static var fatColor: Color { .nutriRed }
    static var sugarColor: Color { .nutriPurple }
    static var waterColor: Color { .nutriBlue }
}
