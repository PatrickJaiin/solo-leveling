import Foundation
import SwiftData

/// Persistent keystone habit. Distinct from variable AI-generated daily quests:
/// habits are the user's own commitments that the System tracks daily for streak weight.
@Model
final class Habit {
    @Attribute(.unique) var id: UUID
    var title: String
    var detail: String
    var pillarRaw: String
    var statRewardRaw: String
    var baseXP: Int
    /// YYYY-MM-DD of the most recent tick (completed today).
    var lastTickDayKey: String?
    var currentStreak: Int
    var bestStreak: Int
    var createdAt: Date
    /// Toggle to pause without deleting (vacations, injuries).
    var paused: Bool

    init(id: UUID = UUID(),
         title: String,
         detail: String = "",
         pillar: Pillar,
         statReward: StatKey? = nil,
         baseXP: Int = 30,
         lastTickDayKey: String? = nil,
         currentStreak: Int = 0,
         bestStreak: Int = 0,
         createdAt: Date = Date(),
         paused: Bool = false) {
        self.id = id
        self.title = title
        self.detail = detail
        self.pillarRaw = pillar.rawValue
        self.statRewardRaw = (statReward ?? pillar.primaryStat).rawValue
        self.baseXP = baseXP
        self.lastTickDayKey = lastTickDayKey
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.createdAt = createdAt
        self.paused = paused
    }

    var pillar: Pillar { Pillar(rawValue: pillarRaw) ?? .work }
    var statReward: StatKey { StatKey(rawValue: statRewardRaw) ?? pillar.primaryStat }

    var tickedToday: Bool { lastTickDayKey == DayKey.key() }
}
