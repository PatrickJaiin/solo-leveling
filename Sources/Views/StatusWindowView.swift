import SwiftUI

/// The Status Window — the player's home for stat allocation, XP debt visibility, and the
/// soft-cap reminder. Mirrors the canon Solo Leveling System screen.
struct StatusWindowView: View {
    @Bindable var hunter: Hunter
    let onDismiss: () -> Void

    @State private var pending: [StatKey: Int] = [:]
    @State private var pulse = false

    var spentPoints: Int { pending.values.reduce(0) { $0 + softCost($1) } }
    var remainingPoints: Int { hunter.unspentPoints - spentPoints }

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea().onTapGesture { onDismiss() }
            SystemPanel(tint: Theme.systemCyan, notch: 22, padding: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    progressionRow
                    Rectangle().fill(Theme.systemCyan.opacity(0.3)).frame(height: 1)
                    statGrid
                    Rectangle().fill(Theme.systemCyan.opacity(0.3)).frame(height: 1)
                    footer
                }
                .frame(width: 560)
            }
            .scaleEffect(pulse ? 1.0 : 0.97)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: pulse)
        }
        .onAppear { pulse = true }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("[ STATUS WINDOW ]")
                .font(Typography.mono(13, weight: .heavy))
                .foregroundStyle(Theme.systemCyan)
                .glow(Theme.systemCyan, radius: 4, intensity: 0.6)
            HStack(spacing: 12) {
                Text(hunter.name)
                    .font(Typography.mono(26, weight: .black))
                    .foregroundStyle(.white)
                SystemTag(text: "LV \(hunter.level)", tint: Theme.systemGold)
                SystemTag(text: "\(hunter.rank.displayName)-RANK", tint: Theme.systemCyan)
                if hunter.inPenaltyZone { SystemTag(text: "PENALTY", tint: Theme.danger) }
            }
        }
    }

    private var progressionRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("XP").font(Typography.systemTag).foregroundStyle(Theme.systemBlue)
                Spacer()
                Text("\(hunter.xp) / \(RankSystem.xpToNext(level: hunter.level))")
                    .font(Typography.body).foregroundStyle(Theme.systemCyan)
            }
            SystemBar(progress: Double(hunter.xp) / Double(RankSystem.xpToNext(level: hunter.level)),
                      tint: Theme.systemCyan)
            if hunter.xpDebt > 0 {
                HStack {
                    Text("DEBT").font(Typography.systemTag).foregroundStyle(Theme.danger)
                    Spacer()
                    Text("-\(hunter.xpDebt)")
                        .font(Typography.body).foregroundStyle(Theme.danger)
                        .glow(Theme.danger, radius: 3, intensity: 0.6)
                }
                SystemBar(progress: 1.0, tint: Theme.danger, height: 5)
                Text("The next \(hunter.xpDebt) XP you earn pays down debt before banking.")
                    .font(Typography.systemTag).foregroundStyle(Theme.danger.opacity(0.85))
            }
        }
    }

    private var statGrid: some View {
        VStack(spacing: 10) {
            statRow(.str, value: hunter.str, passive: "+0.5% Fitness XP / pt above 5 (shared with AGI)")
            statRow(.agi, value: hunter.agi, passive: "Shortens Re-roll cooldown (vs. AGI < cap)")
            statRow(.int, value: hunter.intStat, passive: "+0.5% Work XP / pt above 5")
            statRow(.sen, value: hunter.sen, passive: "Forgives 1% of missed-quest XP debt / pt above 5 (cap 50%)")
            statRow(.vit, value: hunter.vit, passive: "Shortens Sanctioned Rest cooldown by 1 day / 10 pts above 5")
        }
    }

    private func statRow(_ key: StatKey, value: Int, passive: String) -> some View {
        let pendingAdd = pending[key] ?? 0
        let displayValue = value + pendingAdd
        let cap = RankSystem.softCap(for: hunter.rank)
        let overCap = displayValue > cap
        return HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(key.fullName.uppercased() + " · " + key.label)
                    .font(Typography.systemTag)
                    .foregroundStyle(overCap ? Theme.systemGold : Theme.systemCyan)
                Text(passive)
                    .font(Typography.systemTag.weight(.regular))
                    .foregroundStyle(Theme.dim)
            }
            Spacer()
            HStack(spacing: 4) {
                Text("\(displayValue)")
                    .font(Typography.value)
                    .foregroundStyle(overCap ? Theme.systemGold : .white)
                    .frame(minWidth: 36, alignment: .trailing)
                Text("/ \(cap)")
                    .font(Typography.systemTag).foregroundStyle(Theme.dim)
            }
            Button {
                pending[key, default: 0] += 1
                if remainingPoints < 0 { pending[key, default: 0] -= 1 }
            } label: {
                Text("+")
                    .font(Typography.mono(16, weight: .black))
                    .foregroundStyle(canSpend(key) ? Theme.systemCyan : Theme.dim)
                    .frame(width: 32, height: 28)
                    .background(NotchedRectangle(notch: 4).stroke(canSpend(key) ? Theme.systemCyan : Theme.dim.opacity(0.4), lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canSpend(key))

            Button {
                if (pending[key] ?? 0) > 0 { pending[key]! -= 1 }
            } label: {
                Text("−")
                    .font(Typography.mono(16, weight: .black))
                    .foregroundStyle((pending[key] ?? 0) > 0 ? Theme.systemBlue : Theme.dim)
                    .frame(width: 32, height: 28)
                    .background(NotchedRectangle(notch: 4).stroke((pending[key] ?? 0) > 0 ? Theme.systemBlue : Theme.dim.opacity(0.4), lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled((pending[key] ?? 0) == 0)
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("UNSPENT POINTS").font(Typography.systemTag).foregroundStyle(Theme.dim)
                Text("\(remainingPoints)")
                    .font(Typography.huge)
                    .foregroundStyle(remainingPoints > 0 ? Theme.systemGold : Theme.dim)
                    .glow(Theme.systemGold, radius: 4, intensity: remainingPoints > 0 ? 0.6 : 0)
            }
            Spacer()
            Button {
                onDismiss()
            } label: {
                Text("[ DEFER ]")
                    .font(Typography.systemTag).foregroundStyle(Theme.dim)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .overlay(NotchedRectangle(notch: 4).stroke(Theme.dim, lineWidth: 1))
                    .contentShape(NotchedRectangle(notch: 4))
            }
            .buttonStyle(.plain)

            Button {
                apply()
            } label: {
                Text("[ CONFIRM ]")
                    .font(Typography.systemTag).foregroundStyle(Theme.systemCyan)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(NotchedRectangle(notch: 4).fill(Theme.systemCyan.opacity(0.15)))
                    .overlay(NotchedRectangle(notch: 4).stroke(Theme.systemCyan, lineWidth: 1))
                    .contentShape(NotchedRectangle(notch: 4))
            }
            .buttonStyle(.plain)
            .disabled(pending.values.allSatisfy { $0 == 0 })
        }
    }

    private func canSpend(_ key: StatKey) -> Bool {
        let cost = softCost(currentValue(key) + 1 - currentValue(key)) // marginal cost of one more point
        return remainingPoints >= cost
    }

    private func currentValue(_ key: StatKey) -> Int {
        hunter.stat(key) + (pending[key] ?? 0)
    }

    /// Cost of N points spent on a stat (over-cap costs 2x per point above cap — but for simplicity
    /// at this version we use a flat 1pt-per-pt cost. Soft cap is informational only for v0.1).
    private func softCost(_ pointsToAdd: Int) -> Int {
        max(0, pointsToAdd)
    }

    private func apply() {
        for (key, n) in pending where n > 0 {
            hunter.addStat(key, n)
            hunter.unspentPoints -= n
        }
        pending = [:]
        onDismiss()
    }
}
