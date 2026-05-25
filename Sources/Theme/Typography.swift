import SwiftUI

enum Typography {
    /// Monospaced display — used for headings, alerts, "[SYSTEM]" markers.
    static func mono(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Slightly condensed display.
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static let systemTag = Font.system(size: 11, weight: .heavy, design: .monospaced)
    static let panelTitle = Font.system(size: 14, weight: .heavy, design: .monospaced)
    static let body = Font.system(size: 13, weight: .medium, design: .monospaced)
    static let value = Font.system(size: 18, weight: .heavy, design: .monospaced)
    static let huge = Font.system(size: 44, weight: .black, design: .monospaced)
}
