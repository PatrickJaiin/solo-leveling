import SwiftUI
import SwiftData

/// Banner displayed on the Quest Board when a Boss Echo is alive. Loud, ominous, persistent.
struct BossEchoBanner: View {
    let echo: BossEcho

    var body: some View {
        SystemPanel(tint: Theme.danger, notch: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .foregroundStyle(Theme.danger)
                        .glow(Theme.danger, radius: 6, intensity: 0.9)
                    Text("[ ECHO ALIVE — \(echo.name.uppercased()) ]")
                        .font(Typography.panelTitle).foregroundStyle(Theme.danger)
                        .glow(Theme.danger, radius: 3, intensity: 0.7)
                    Spacer()
                    SystemTag(text: echo.pillar.label, tint: echo.pillar.tint)
                }
                Text(echo.flavor)
                    .font(Typography.body).foregroundStyle(.white.opacity(0.9))
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("KILL CONDITION")
                            .font(Typography.systemTag).foregroundStyle(Theme.dim)
                        Text(echo.killCondition)
                            .font(Typography.body).foregroundStyle(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(echo.progress) / \(echo.requiredHits)")
                            .font(Typography.value).foregroundStyle(Theme.danger)
                        SystemBar(progress: echo.fractionDone, tint: Theme.danger)
                            .frame(width: 140, height: 6)
                        Text("Debuff: \(Int((1 - echo.debuff) * 100))% on \(echo.pillar.label) XP")
                            .font(Typography.systemTag).foregroundStyle(Theme.danger.opacity(0.9))
                    }
                }
            }
        }
    }
}
