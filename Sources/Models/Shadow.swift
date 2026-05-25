import Foundation
import SwiftData

@Model
final class Shadow {
    @Attribute(.unique) var id: UUID
    var name: String
    var sourceQuestTitle: String
    var pillarRaw: String
    /// Bonus type: "xp_multiplier", "stat_bonus", "streak_protect"
    var bonusType: String
    var bonusValue: Double
    var extractedAt: Date
    /// Number of consecutive completions that produced this shadow.
    var sourceStreak: Int

    init(id: UUID = UUID(),
         name: String,
         sourceQuestTitle: String,
         pillar: Pillar,
         bonusType: String,
         bonusValue: Double,
         extractedAt: Date = Date(),
         sourceStreak: Int) {
        self.id = id
        self.name = name
        self.sourceQuestTitle = sourceQuestTitle
        self.pillarRaw = pillar.rawValue
        self.bonusType = bonusType
        self.bonusValue = bonusValue
        self.extractedAt = extractedAt
        self.sourceStreak = sourceStreak
    }

    var pillar: Pillar { Pillar(rawValue: pillarRaw) ?? .work }
}
