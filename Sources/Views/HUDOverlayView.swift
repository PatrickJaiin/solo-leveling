import SwiftUI
import SwiftData

/// Always-on-top floating HUD — compact quest log + XP bar.
/// Queries Hunter directly so it always reads from the same store as the main window.
struct HUDOverlayView: View {
    @Environment(\.modelContext) private var context
    @Environment(QuestEngine.self) private var engine

    @Query private var hunters: [Hunter]
    @Query(sort: \Quest.assignedAt, order: .forward) private var allQuests: [Quest]

    var hunter: Hunter? { hunters.first }
    var todayQuests: [Quest] { allQuests.filter { $0.dayKey == DayKey.key() } }

    var body: some View {
        Group {
            if let hunter {
                SystemPanel(tint: Theme.systemBlue, notch: 12, padding: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("LV \(hunter.level) \(hunter.rank.displayName)")
                                .font(Typography.systemTag).foregroundStyle(Theme.systemCyan)
                            Spacer()
                            Text("\(completedCount)/\(todayQuests.count)")
                                .font(Typography.systemTag).foregroundStyle(Theme.systemGold)
                        }
                        SystemBar(progress: Double(hunter.xp) / Double(RankSystem.xpToNext(level: hunter.level)),
                                  tint: Theme.systemCyan, height: 5)
                        ForEach(todayQuests.prefix(5)) { q in
                            Button {
                                if q.status == .assigned {
                                    engine.complete(quest: q, hunter: hunter, context: context)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Circle()
                                        .stroke(q.pillar.tint, lineWidth: 1.2)
                                        .background(Circle().fill(q.status == .completed ? q.pillar.tint.opacity(0.6) : .clear))
                                        .frame(width: 12, height: 12)
                                    Text(q.title)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(q.status == .completed ? Theme.dim : .white)
                                        .strikethrough(q.status == .completed)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(width: 280)
                }
                .padding(8)
            } else {
                EmptyView()
            }
        }
    }

    private var completedCount: Int { todayQuests.filter { $0.status == .completed }.count }
}
