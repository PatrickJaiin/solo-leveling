import Foundation

enum RankSystem {
    /// XP required to advance from `level` to `level+1`.
    static func xpToNext(level: Int) -> Int {
        100 + (level - 1) * 50
    }

    struct LevelUpResult: Identifiable {
        let id: UUID = UUID()
        var didLevelUp: Bool
        var levelsGained: Int
        var newLevel: Int
        var pointsGained: Int
        var rankChangedTo: Rank?
    }

    /// Adds XP to the hunter; rolls over levels and returns a summary.
    @discardableResult
    static func grantXP(_ amount: Int, to hunter: Hunter) -> LevelUpResult {
        let startRank = hunter.rank
        var levels = 0
        var points = 0
        hunter.xp += amount
        while hunter.xp >= xpToNext(level: hunter.level) {
            hunter.xp -= xpToNext(level: hunter.level)
            hunter.level += 1
            levels += 1
            points += 3
        }
        hunter.unspentPoints += points
        let endRank = hunter.rank
        return LevelUpResult(
            didLevelUp: levels > 0,
            levelsGained: levels,
            newLevel: hunter.level,
            pointsGained: points,
            rankChangedTo: endRank != startRank ? endRank : nil
        )
    }

    /// Suggest a title based on rank, level, and lifetime completions.
    static func suggestedTitle(for hunter: Hunter) -> String {
        switch hunter.rank {
        case .E: return "The Weakest E-Rank"
        case .D: return "Apprentice Hunter"
        case .C: return "Field Hunter"
        case .B: return "Elite Hunter"
        case .A: return "Ace Hunter"
        case .S: return "S-Rank Hunter"
        case .SS: return "Monarch's Shadow"
        case .NATIONAL: return "National-Level Hunter"
        }
    }
}
