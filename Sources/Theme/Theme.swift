import SwiftUI

enum Theme {
    // Base palette
    static let bg = Color(red: 0.020, green: 0.027, blue: 0.055)
    static let bgElevated = Color(red: 0.030, green: 0.045, blue: 0.090)
    static let panel = Color(red: 0.043, green: 0.075, blue: 0.137).opacity(0.70)
    static let panelStroke = Color(red: 0.36, green: 0.82, blue: 1.0).opacity(0.55)
    static let panelStrokeStrong = Color(red: 0.58, green: 0.92, blue: 1.0)

    // Accent
    static let systemBlue = Color(red: 0.36, green: 0.82, blue: 1.0)
    static let systemCyan = Color(red: 0.58, green: 0.95, blue: 1.0)
    static let systemGold = Color(red: 1.0, green: 0.84, blue: 0.45)
    static let danger = Color(red: 1.0, green: 0.31, blue: 0.31)
    static let success = Color(red: 0.36, green: 1.0, blue: 0.70)
    static let dim = Color(white: 0.68)

    // Gradients
    static let panelFill = LinearGradient(
        colors: [
            Color(red: 0.030, green: 0.080, blue: 0.180).opacity(0.85),
            Color(red: 0.015, green: 0.040, blue: 0.110).opacity(0.85)
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let strokeGradient = LinearGradient(
        colors: [
            Color(red: 0.58, green: 0.95, blue: 1.0).opacity(0.95),
            Color(red: 0.20, green: 0.55, blue: 0.95).opacity(0.55)
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let bgGradient = RadialGradient(
        colors: [
            Color(red: 0.035, green: 0.060, blue: 0.130),
            Color(red: 0.010, green: 0.015, blue: 0.040)
        ],
        center: .center, startRadius: 50, endRadius: 900
    )
}
