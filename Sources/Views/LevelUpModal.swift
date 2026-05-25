import SwiftUI

struct LevelUpModal: View {
    let result: RankSystem.LevelUpResult
    let onDismiss: () -> Void
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .onTapGesture { onDismiss() }
            SystemPanel(tint: Theme.systemGold, notch: 22, padding: 28) {
                VStack(spacing: 16) {
                    Text("[ LEVEL UP ]")
                        .font(Typography.mono(18, weight: .black))
                        .foregroundStyle(Theme.systemGold)
                        .glow(Theme.systemGold, radius: 8, intensity: 1.0)
                    Text("\(result.newLevel)")
                        .font(Typography.huge)
                        .foregroundStyle(.white)
                        .glow(Theme.systemGold, radius: 14, intensity: 1.0)
                        .scaleEffect(pulse ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
                    if let rank = result.rankChangedTo {
                        Text("PROMOTED TO \(rank.displayName)-RANK")
                            .font(Typography.panelTitle).foregroundStyle(Theme.systemCyan)
                            .glow(Theme.systemCyan, radius: 4, intensity: 0.7)
                    }
                    HStack(spacing: 18) {
                        statBubble("+\(result.levelsGained)", "LEVELS")
                        statBubble("+\(result.pointsGained)", "STAT PTS")
                    }
                    Button {
                        onDismiss()
                    } label: {
                        Text("[ CONTINUE ]")
                            .font(Typography.systemTag).foregroundStyle(Theme.systemCyan)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(NotchedRectangle(notch: 4).fill(Theme.systemCyan.opacity(0.08)))
                            .overlay(NotchedRectangle(notch: 4).stroke(Theme.systemCyan, lineWidth: 1))
                            .contentShape(NotchedRectangle(notch: 4))
                    }
                    .buttonStyle(.plain)
                }
                .frame(minWidth: 360)
            }
            .frame(maxWidth: 460)
            .padding(40)
        }
        .onAppear { pulse = true }
    }

    private func statBubble(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(Typography.value).foregroundStyle(Theme.systemGold)
            Text(label).font(Typography.systemTag).foregroundStyle(Theme.dim)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(NotchedRectangle(notch: 6).stroke(Theme.systemGold.opacity(0.6), lineWidth: 1))
    }
}
