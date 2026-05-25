import SwiftUI

/// The signature "[ System ]" translucent panel — angular corners, glow border, monospace.
struct SystemPanel<Content: View>: View {
    var title: String?
    var tint: Color = Theme.systemBlue
    var notch: CGFloat = 14
    var padding: CGFloat = 16
    var content: () -> Content

    init(_ title: String? = nil,
         tint: Color = Theme.systemBlue,
         notch: CGFloat = 14,
         padding: CGFloat = 16,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.tint = tint
        self.notch = notch
        self.padding = padding
        self.content = content
    }

    var body: some View {
        ZStack {
            NotchedRectangle(notch: notch)
                .fill(Theme.panelFill)
                .overlay(
                    NotchedRectangle(notch: notch)
                        .stroke(Theme.strokeGradient, lineWidth: 1.2)
                )
                .overlay(
                    NotchedRectangle(notch: notch)
                        .stroke(tint.opacity(0.85), lineWidth: 0.6)
                        .blur(radius: 1.5)
                )
                .glow(tint.opacity(0.6), radius: 10, intensity: 0.55)

            VStack(alignment: .leading, spacing: 10) {
                if let title {
                    HStack(spacing: 8) {
                        Text("[ \(title.uppercased()) ]")
                            .font(Typography.systemTag)
                            .foregroundStyle(tint)
                            .glow(tint, radius: 4, intensity: 0.6)
                        Rectangle()
                            .fill(LinearGradient(colors: [tint.opacity(0.7), .clear],
                                                  startPoint: .leading, endPoint: .trailing))
                            .frame(height: 1)
                    }
                }
                content()
            }
            .padding(padding)
        }
    }
}

/// Small "tag" pill — used for status indicators, ranks, pillar labels.
struct SystemTag: View {
    var text: String
    var tint: Color = Theme.systemBlue

    var body: some View {
        Text(text.uppercased())
            .font(Typography.systemTag)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                NotchedRectangle(notch: 4)
                    .stroke(tint.opacity(0.9), lineWidth: 1)
                    .background(
                        NotchedRectangle(notch: 4).fill(tint.opacity(0.10))
                    )
            )
    }
}

/// Horizontal XP / progress bar with glowing fill.
struct SystemBar: View {
    var progress: Double  // 0...1
    var tint: Color = Theme.systemCyan
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .overlay(Rectangle().stroke(tint.opacity(0.4), lineWidth: 0.5))
                Rectangle()
                    .fill(LinearGradient(colors: [tint, tint.opacity(0.7)],
                                          startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(2, geo.size.width * min(max(progress, 0), 1)))
                    .glow(tint, radius: 6, intensity: 0.7)
            }
        }
        .frame(height: height)
    }
}
