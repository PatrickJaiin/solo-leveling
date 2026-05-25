import Foundation
import SwiftData

@Model
final class DailyLog {
    @Attribute(.unique) var dayKey: String
    var date: Date
    var questsAssigned: Int
    var questsCompleted: Int
    var questsMissed: Int
    var xpEarned: Int
    var enteredPenalty: Bool
    var notes: String

    init(dayKey: String,
         date: Date = Date(),
         questsAssigned: Int = 0,
         questsCompleted: Int = 0,
         questsMissed: Int = 0,
         xpEarned: Int = 0,
         enteredPenalty: Bool = false,
         notes: String = "") {
        self.dayKey = dayKey
        self.date = date
        self.questsAssigned = questsAssigned
        self.questsCompleted = questsCompleted
        self.questsMissed = questsMissed
        self.xpEarned = xpEarned
        self.enteredPenalty = enteredPenalty
        self.notes = notes
    }

    var completionRate: Double {
        guard questsAssigned > 0 else { return 0 }
        return Double(questsCompleted) / Double(questsAssigned)
    }
}
