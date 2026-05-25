import Foundation
import SwiftData

@Model
final class Quest {
    @Attribute(.unique) var id: UUID

    var title: String
    var detail: String
    var pillarRaw: String
    var difficultyRaw: String
    var statusRaw: String

    /// Base XP awarded (before multipliers).
    var baseXP: Int

    /// Primary stat awarded on completion (e.g. "str", "int").
    var statRewardRaw: String
    var statRewardAmount: Int

    /// YYYY-MM-DD for the day this quest is assigned to.
    var dayKey: String

    var assignedAt: Date
    var completedAt: Date?

    /// True if this quest was forcibly generated as part of a Penalty Zone day.
    var isPenalty: Bool

    /// True for the weekly Sunday "dungeon" quest.
    var isDungeon: Bool

    /// AI-tagged. If true, HealthKit/EventKit may auto-complete it.
    var autoCompletable: Bool

    /// Optional source tag: "ai" | "template" | "manual" | "shadow".
    var source: String

    init(id: UUID = UUID(),
         title: String,
         detail: String = "",
         pillar: Pillar,
         difficulty: Difficulty = .normal,
         status: QuestStatus = .assigned,
         baseXP: Int = 50,
         statReward: StatKey? = nil,
         statRewardAmount: Int = 1,
         dayKey: String,
         assignedAt: Date = Date(),
         completedAt: Date? = nil,
         isPenalty: Bool = false,
         isDungeon: Bool = false,
         autoCompletable: Bool = false,
         source: String = "manual") {
        self.id = id
        self.title = title
        self.detail = detail
        self.pillarRaw = pillar.rawValue
        self.difficultyRaw = difficulty.rawValue
        self.statusRaw = status.rawValue
        self.baseXP = baseXP
        self.statRewardRaw = (statReward ?? pillar.primaryStat).rawValue
        self.statRewardAmount = statRewardAmount
        self.dayKey = dayKey
        self.assignedAt = assignedAt
        self.completedAt = completedAt
        self.isPenalty = isPenalty
        self.isDungeon = isDungeon
        self.autoCompletable = autoCompletable
        self.source = source
    }

    var pillar: Pillar { Pillar(rawValue: pillarRaw) ?? .work }
    var difficulty: Difficulty { Difficulty(rawValue: difficultyRaw) ?? .normal }
    var status: QuestStatus {
        get { QuestStatus(rawValue: statusRaw) ?? .assigned }
        set { statusRaw = newValue.rawValue }
    }
    var statReward: StatKey { StatKey(rawValue: statRewardRaw) ?? pillar.primaryStat }

    var effectiveXP: Int {
        let mult = difficulty.xpMultiplier * (isPenalty ? 1.5 : 1.0) * (isDungeon ? 3.0 : 1.0)
        return Int(Double(baseXP) * mult)
    }
}
