import SwiftUI
import SwiftData

struct StatSheetView: View {
    let hunter: Hunter
    @Environment(\.modelContext) private var context
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SystemPanel("Character Sheet", tint: Theme.systemBlue, notch: 18) {
                    HStack(alignment: .top, spacing: 30) {
                        VStack(alignment: .leading, spacing: 14) {
                            row("Name", hunter.name)
                            row("Title", hunter.title)
                            row("Class", hunter.rank.displayName + "-Rank Hunter")
                            row("Level", "\(hunter.level)")
                            row("Streak", "\(hunter.dayStreak) days")
                            row("Lifetime Quests", "\(hunter.lifetimeQuestsCompleted)")
                            row("Unspent Points", "\(hunter.unspentPoints)")
                        }
                        Divider().background(Theme.systemBlue.opacity(0.4))
                        VStack(alignment: .leading, spacing: 12) {
                            statBar(.str, hunter.str)
                            statBar(.agi, hunter.agi)
                            statBar(.int, hunter.intStat)
                            statBar(.sen, hunter.sen)
                            statBar(.vit, hunter.vit)
                        }
                    }
                }

                SystemPanel("Rank Progression", tint: Theme.systemGold) {
                    HStack(spacing: 10) {
                        ForEach(Rank.order, id: \.self) { rank in
                            VStack(spacing: 4) {
                                Text(rank.displayName == "NATIONAL" ? "NTL" : rank.rawValue)
                                    .font(Typography.systemTag)
                                    .foregroundStyle(hunter.rank >= rank ? Theme.systemGold : Theme.dim)
                                Text("L\(rank.threshold)")
                                    .font(Typography.systemTag.weight(.regular))
                                    .foregroundStyle(Theme.dim)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                NotchedRectangle(notch: 5)
                                    .stroke(hunter.rank >= rank ? Theme.systemGold : Theme.dim.opacity(0.3), lineWidth: 1)
                            )
                            if rank != .NATIONAL {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10)).foregroundStyle(Theme.dim)
                            }
                        }
                    }
                }

                SystemPanel("Recent Log", tint: Theme.systemBlue) {
                    if logs.isEmpty {
                        Text("No history yet. Complete a few quests to start your log.")
                            .font(Typography.body).foregroundStyle(Theme.dim)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(logs.prefix(10)) { log in
                                HStack {
                                    Text(log.dayKey).font(Typography.body).foregroundStyle(Theme.systemCyan)
                                    Spacer()
                                    Text("\(log.questsCompleted)/\(log.questsAssigned)")
                                        .font(Typography.body).foregroundStyle(.white)
                                    Text("+\(log.xpEarned) XP")
                                        .font(Typography.body).foregroundStyle(Theme.systemGold)
                                        .frame(width: 80, alignment: .trailing)
                                    if log.enteredPenalty {
                                        SystemTag(text: "PEN", tint: Theme.danger)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k.uppercased()).font(Typography.systemTag).foregroundStyle(Theme.dim).frame(width: 130, alignment: .leading)
            Text(v).font(Typography.body).foregroundStyle(.white)
        }
    }

    private func statBar(_ key: StatKey, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(key.fullName.uppercased() + " (" + key.label + ")")
                    .font(Typography.systemTag).foregroundStyle(Theme.systemCyan)
                Spacer()
                Text("\(value)").font(Typography.value).foregroundStyle(.white)
            }
            SystemBar(progress: Double(value) / 100.0, tint: Theme.systemCyan)
                .frame(width: 240)
        }
    }
}
