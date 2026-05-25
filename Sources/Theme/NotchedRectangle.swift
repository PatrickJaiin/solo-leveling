import SwiftUI

/// A rectangle with the four corners cut at 45° — the signature "System" frame shape.
struct NotchedRectangle: Shape {
    var notch: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        let n = min(notch, min(rect.width, rect.height) / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + n, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - n, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + n))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - n))
        p.addLine(to: CGPoint(x: rect.maxX - n, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + n, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - n))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + n))
        p.closeSubpath()
        return p
    }
}
