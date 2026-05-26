import Foundation
import SwiftData

/// Boss Echoes — AI-summoned adversaries born from the Hunter's failure data.
/// Replaces the streak-based Shadow extraction (which was brittle when AI generates titles).
/// Killing an Echo creates a Shadow as a trophy.
@MainActor
enum BossEchoService {
    /// Inspect the last `window` days of DailyLog + Quest records and decide whether to spawn an Echo.
    /// Returns the newly-spawned echo, or nil if nothing dire enough.
    static func considerSpawn(hunter: Hunter, context: ModelContext, windowDays: Int = 14) -> BossEcho? {
        // Don't stack: one active echo at a time.
        let alive = (try? context.fetch(FetchDescriptor<BossEcho>(predicate: #Predicate { !$0.dispatched }))) ?? []
        if alive.contains(where: { $0.isAlive }) { return nil }

        // Don't spawn during the user's Sanctioned Rest day.
        if hunter.activeRestDayKey == DayKey.key() { return nil }

        // Compute per-pillar miss counts in the recent window.
        let fromDate = Calendar.current.date(byAdding: .day, value: -windowDays, to: Date()) ?? Date()
        let fromKey = DayKey.key(for: fromDate)
        let recent = (try? context.fetch(FetchDescriptor<Quest>(predicate: #Predicate { $0.dayKey >= fromKey }))) ?? []
        var missedByPillar: [Pillar: Int] = [:]
        var totalByPillar: [Pillar: Int] = [:]
        for q in recent {
            totalByPillar[q.pillar, default: 0] += 1
            if q.status == .missed { missedByPillar[q.pillar, default: 0] += 1 }
        }

        // Find the worst pillar — must be at least 4 misses AND miss rate > 50%.
        var worst: (Pillar, Int)? = nil
        for (p, missed) in missedByPillar {
            let total = totalByPillar[p] ?? 0
            guard total > 0, missed >= 4, Double(missed) / Double(total) > 0.5 else { continue }
            if worst == nil || missed > worst!.1 { worst = (p, missed) }
        }
        guard let (pillar, _) = worst else { return nil }

        let proto = bossPrototype(for: pillar)
        let expiry = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        let echo = BossEcho(name: proto.name,
                            flavor: proto.flavor,
                            pillar: pillar,
                            killCondition: proto.killCondition,
                            requiredHits: proto.requiredHits,
                            debuff: proto.debuff,
                            expiresAt: expiry)
        context.insert(echo)
        return echo
    }

    /// Called from `QuestEngine.complete`. If a matching-pillar hard-or-extreme quest was just
    /// completed, advance the Echo's progress. If the Echo is now dead, convert it to a Shadow.
    static func registerHit(quest: Quest, hunter: Hunter, context: ModelContext) -> (advanced: Bool, killed: BossEcho?) {
        guard let echo = (try? context.fetch(FetchDescriptor<BossEcho>(predicate: #Predicate { !$0.dispatched })))?.first(where: { $0.isAlive }) else {
            return (false, nil)
        }
        guard quest.pillar == echo.pillar else { return (false, nil) }
        // Only hard/extreme counts as a "hit" — keeps Echoes meaningful.
        guard quest.difficulty == .hard || quest.difficulty == .extreme else { return (false, nil) }
        echo.progress += 1
        if echo.progress >= echo.requiredHits {
            echo.dispatched = true
            echo.dispatchedAt = Date()
            // Trophy: a Shadow joins the army.
            let shadow = Shadow(name: "\(echo.name) (Echo)",
                                sourceQuestTitle: echo.killCondition,
                                pillar: echo.pillar,
                                bonusType: "xp_multiplier",
                                bonusValue: 0.10,
                                sourceStreak: echo.requiredHits)
            context.insert(shadow)
            return (true, echo)
        }
        return (true, nil)
    }

    /// Multiplier on XP gain for this pillar caused by an active Echo. < 1.0 = debuff.
    static func activeDebuff(for pillar: Pillar, context: ModelContext) -> Double {
        let echoes = (try? context.fetch(FetchDescriptor<BossEcho>(predicate: #Predicate { !$0.dispatched }))) ?? []
        for e in echoes where e.isAlive && e.pillar == pillar {
            return e.debuff
        }
        return 1.0
    }

    // MARK: - Prototype catalog

    private struct Prototype {
        let name: String
        let flavor: String
        let killCondition: String
        let requiredHits: Int
        let debuff: Double
    }

    private static func bossPrototype(for pillar: Pillar) -> Prototype {
        switch pillar {
        case .fitness:
            return Prototype(
                name: "The Slouch",
                flavor: "Born from days the body was not asked to move. Feeds on inertia. Tone deaf to your spreadsheet.",
                killCondition: "Complete 3 hard fitness quests within 3 days.",
                requiredHits: 3,
                debuff: 0.75)
        case .work:
            return Prototype(
                name: "The Drift",
                flavor: "It does not stop you from working. It stops you from finishing. Made of every half-closed tab.",
                killCondition: "Complete 3 hard work quests within 3 days.",
                requiredHits: 3,
                debuff: 0.75)
        case .mental:
            return Prototype(
                name: "The Static",
                flavor: "A hum behind every thought. It does not lie — but it never lets you arrive at the lie's edge.",
                killCondition: "Complete 3 hard mental quests within 3 days.",
                requiredHits: 3,
                debuff: 0.75)
        case .vitality:
            return Prototype(
                name: "The Wick",
                flavor: "Long, low burn. You will not notice it until it goes out. Then everything else falls.",
                killCondition: "Complete 3 hard vitality quests within 3 days.",
                requiredHits: 3,
                debuff: 0.75)
        }
    }
}
