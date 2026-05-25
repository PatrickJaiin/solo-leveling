import SwiftUI

struct GlowModifier: ViewModifier {
    var color: Color = Theme.systemCyan
    var radius: CGFloat = 6
    var intensity: Double = 0.9

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(intensity * 0.9), radius: radius * 0.5)
            .shadow(color: color.opacity(intensity * 0.5), radius: radius)
            .shadow(color: color.opacity(intensity * 0.25), radius: radius * 2)
    }
}

extension View {
    func glow(_ color: Color = Theme.systemCyan, radius: CGFloat = 6, intensity: Double = 0.9) -> some View {
        modifier(GlowModifier(color: color, radius: radius, intensity: intensity))
    }
}
