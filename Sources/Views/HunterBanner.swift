import SwiftUI

struct HunterBanner: View {
    let hunter: Hunter

    var xpToNext: Int { RankSystem.xpToNext(level: hunter.level) }

    var body: some View {
        SystemPanel("Hunter Profile", tint: Theme.systemBlue, notch: 18) {
            HStack(alignment: .center, spacing: 20) {
                rankBadge
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text(hunter.name)
                            .font(Typography.mono(22, weight: .black))
                            .foregroundStyle(Theme.systemCyan)
                            .glow(Theme.systemCyan, radius: 4, intensity: 0.6)
                        SystemTag(text: "LV \(hunter.level)", tint: Theme.systemGold)
                        if hunter.inPenaltyZone {
                            SystemTag(text: "PENALTY", tint: Theme.danger)
                        }
                    }
                    Text(hunter.title)
                        .font(Typography.body)
                        .foregroundStyle(Theme.dim)
                    HStack(spacing: 6) {
                        Text("XP")
                            .font(Typography.systemTag)
                            .foregroundStyle(Theme.systemBlue)
                        SystemBar(progress: Double(hunter.xp) / Double(xpToNext), tint: Theme.systemCyan)
                            .frame(maxWidth: 380)
                        Text("\(hunter.xp) / \(xpToNext)")
                            .font(Typography.body)
                            .foregroundStyle(Theme.systemCyan)
                    }
                    HStack(spacing: 14) {
                        statChip(.str, hunter.str)
                        statChip(.agi, hunter.agi)
                        statChip(.int, hunter.intStat)
                        statChip(.sen, hunter.sen)
                        statChip(.vit, hunter.vit)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("STREAK")
                                .font(Typography.systemTag).foregroundStyle(Theme.dim)
                            Text("\(hunter.dayStreak)d")
                                .font(Typography.value).foregroundStyle(Theme.systemGold)
                                .glow(Theme.systemGold, radius: 3, intensity: 0.5)
                        }
                    }
                }
            }
        }
    }

    private var rankBadge: some View {
        ZStack {
            NotchedRectangle(notch: 10)
                .fill(LinearGradient(colors: [Theme.systemBlue.opacity(0.4), Theme.bgElevated],
                                      startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 70, height: 90)
                .overlay(NotchedRectangle(notch: 10).stroke(Theme.systemCyan, lineWidth: 1.2))
                .glow(Theme.systemCyan, radius: 8, intensity: 0.8)
            VStack(spacing: 2) {
                Text("RANK")
                    .font(Typography.systemTag).foregroundStyle(Theme.dim)
                Text(hunter.rank.displayName)
                    .font(Typography.mono(28, weight: .black))
                    .foregroundStyle(Theme.systemCyan)
                    .glow(Theme.systemCyan, radius: 4, intensity: 0.9)
            }
        }
    }

    private func statChip(_ key: StatKey, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text(key.label).font(Typography.systemTag).foregroundStyle(Theme.dim)
            Text("\(value)").font(Typography.value).foregroundStyle(.white)
        }
        .frame(minWidth: 38)
    }
}
