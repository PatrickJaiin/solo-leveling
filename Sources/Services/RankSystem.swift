import Foundation

enum RankSystem {
    /// XP required to advance from `level` to `level+1`.
    ///
    /// Curve: linear-quadratic — 80 + 20·L. At ~500 XP/day this puts D-rank in ~2 weeks,
    /// C in ~2 months, B in ~5 months, S in ~9 months, NATIONAL in ~2 years. Aspirational
    /// but actually reachable; previous curve made NATIONAL a ~17 year horizon.
    static func xpToNext(level: Int) -> Int {
        80 + 20 * max(level, 1)
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
    /// Honors `xpDebt`: any positive debt is paid down before new XP banks.
    @discardableResult
    static func grantXP(_ amount: Int, to hunter: Hunter) -> LevelUpResult {
        let startRank = hunter.rank
        var remaining = amount

        // Pay off debt first.
        if hunter.xpDebt > 0 {
            let pay = min(remaining, hunter.xpDebt)
            hunter.xpDebt -= pay
            remaining -= pay
        }

        var levels = 0
        var points = 0
        if remaining > 0 {
            hunter.xp += remaining
            while hunter.xp >= xpToNext(level: hunter.level) {
                hunter.xp -= xpToNext(level: hunter.level)
                hunter.level += 1
                levels += 1
                points += 3
            }
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

    /// Suggest a title based on rank.
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

    /// Soft cap on any single stat at the Hunter's current rank.
    /// Going over the cap costs 2 stat points per stat above the cap.
    static func softCap(for rank: Rank) -> Int {
        switch rank {
        case .E: 30
        case .D: 50
        case .C: 70
        case .B: 90
        case .A: 110
        case .S: 140
        case .SS: 180
        case .NATIONAL: 240
        }
    }
}

/// Passive modifiers derived from the Hunter's stats. Read by the quest engine
/// when granting XP and when accruing debt. Pure function of `Hunter` state —
/// keep it that way so save/load is trivial.
struct Modifiers {
    /// Multiplicative XP gain bonus on Work-pillar quests (driven by INT).
    var workXpBonus: Double
    /// Multiplicative XP gain bonus on Fitness-pillar quests (driven by STR + AGI).
    var fitnessXpBonus: Double
    /// Multiplicative XP gain bonus on Mental-pillar quests (driven by SEN).
    var mentalXpBonus: Double
    /// Multiplicative XP gain bonus on Vitality-pillar quests (driven by VIT).
    var vitalityXpBonus: Double
    /// Fraction (0..1) of the would-be XP debt that is forgiven on miss.
    var debtForgiveness: Double
    /// Days between Sanctioned Rest invocations (shorter = more often). Default 14.
    var restCooldownDays: Int

    static func from(_ hunter: Hunter) -> Modifiers {
        // Each point of a stat above 5 grants a 0.5% bonus to its pillar.
        let workBonus = max(0, hunter.intStat - 5)
        let fitBonus = max(0, (hunter.str + hunter.agi) / 2 - 5)
        let mentalBonus = max(0, hunter.sen - 5)
        let vitBonus = max(0, hunter.vit - 5)

        return Modifiers(
            workXpBonus: 1.0 + Double(workBonus) * 0.005,
            fitnessXpBonus: 1.0 + Double(fitBonus) * 0.005,
            mentalXpBonus: 1.0 + Double(mentalBonus) * 0.005,
            vitalityXpBonus: 1.0 + Double(vitBonus) * 0.005,
            // SEN forgives debt: each point above 5 forgives 1% of would-be debt, capped 50%.
            debtForgiveness: min(0.5, Double(mentalBonus) * 0.01),
            // VIT shortens rest cooldown by 1 day per 10 above 5, floor 7.
            restCooldownDays: max(7, 14 - vitBonus / 10)
        )
    }

    func multiplier(for pillar: Pillar) -> Double {
        switch pillar {
        case .work: workXpBonus
        case .fitness: fitnessXpBonus
        case .mental: mentalXpBonus
        case .vitality: vitalityXpBonus
        }
    }
}
