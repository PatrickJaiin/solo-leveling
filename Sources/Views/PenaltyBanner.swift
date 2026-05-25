import SwiftUI

struct PenaltyBanner: View {
    var body: some View {
        SystemPanel(tint: Theme.danger, notch: 10) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.danger)
                    .glow(Theme.danger, radius: 6, intensity: 0.9)
                VStack(alignment: .leading, spacing: 2) {
                    Text("[ PENALTY ZONE ACTIVATED ]")
                        .font(Typography.panelTitle)
                        .foregroundStyle(Theme.danger)
                    Text("You failed more than half of yesterday's quests. Today's set has been escalated. Complete at least 50% to restore standing.")
                        .font(Typography.body)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
            }
        }
    }
}
