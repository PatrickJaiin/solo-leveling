import Foundation
import SwiftData

@Model
final class Hunter {
    var name: String
    var title: String
    var level: Int
    var xp: Int

    var str: Int
    var agi: Int
    var intStat: Int
    var sen: Int
    var vit: Int

    /// Unallocated stat points the user can spend on level-up.
    var unspentPoints: Int

    /// Total quests completed across all time (drives some title/rank unlocks).
    var lifetimeQuestsCompleted: Int

    /// YYYY-MM-DD of the last day for which quests were generated.
    var lastQuestDayKey: String

    /// YYYY-MM-DD of the last completed daily reset (drives the streak meter).
    var lastActiveDayKey: String

    /// Consecutive days with >=1 completed non-penalty quest.
    var dayStreak: Int

    /// If true, today started in the Penalty Zone (more than half of yesterday's quests were missed).
    var inPenaltyZone: Bool

    init(name: String = "Hunter",
         title: String = "The Weakest E-Rank",
         level: Int = 1,
         xp: Int = 0,
         str: Int = 5,
         agi: Int = 5,
         intStat: Int = 5,
         sen: Int = 5,
         vit: Int = 5,
         unspentPoints: Int = 0,
         lifetimeQuestsCompleted: Int = 0,
         lastQuestDayKey: String = "",
         lastActiveDayKey: String = "",
         dayStreak: Int = 0,
         inPenaltyZone: Bool = false) {
        self.name = name
        self.title = title
        self.level = level
        self.xp = xp
        self.str = str
        self.agi = agi
        self.intStat = intStat
        self.sen = sen
        self.vit = vit
        self.unspentPoints = unspentPoints
        self.lifetimeQuestsCompleted = lifetimeQuestsCompleted
        self.lastQuestDayKey = lastQuestDayKey
        self.lastActiveDayKey = lastActiveDayKey
        self.dayStreak = dayStreak
        self.inPenaltyZone = inPenaltyZone
    }

    var rank: Rank { Rank.forLevel(level) }

    func stat(_ key: StatKey) -> Int {
        switch key {
        case .str: str
        case .agi: agi
        case .int: intStat
        case .sen: sen
        case .vit: vit
        }
    }

    func addStat(_ key: StatKey, _ amount: Int) {
        switch key {
        case .str: str += amount
        case .agi: agi += amount
        case .int: intStat += amount
        case .sen: sen += amount
        case .vit: vit += amount
        }
    }
}
