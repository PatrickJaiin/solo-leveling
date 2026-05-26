import Foundation
import SwiftData

/// AI-summoned adversary representing the Hunter's recent failure pattern.
/// Active for up to ~3 days; cleared by completing the kill condition; collapses (penalizes) on timeout.
@Model
final class BossEcho {
    @Attribute(.unique) var id: UUID
    var name: String                  // "The Slouch", "The Drift", "The Coward"
    var flavor: String                // 1-2 sentence in-character description
    var pillarRaw: String             // pillar being attacked
    /// e.g. "complete a hard fitness quest on 3 consecutive days"
    var killCondition: String
    /// Daily progress toward the kill condition. Engine increments this when matching quests complete.
    var progress: Int
    /// How many "hits" are required to kill the Echo.
    var requiredHits: Int
    /// Multiplier applied to the named pillar's XP gain (e.g. 0.75 = 25% debuff) while alive.
    var debuff: Double
    var spawnedAt: Date
    var expiresAt: Date
    var dispatched: Bool              // true once the user has killed it
    var dispatchedAt: Date?

    init(id: UUID = UUID(),
         name: String,
         flavor: String,
         pillar: Pillar,
         killCondition: String,
         requiredHits: Int,
         debuff: Double = 0.75,
         spawnedAt: Date = Date(),
         expiresAt: Date,
         progress: Int = 0,
         dispatched: Bool = false) {
        self.id = id
        self.name = name
        self.flavor = flavor
        self.pillarRaw = pillar.rawValue
        self.killCondition = killCondition
        self.requiredHits = requiredHits
        self.debuff = debuff
        self.spawnedAt = spawnedAt
        self.expiresAt = expiresAt
        self.progress = progress
        self.dispatched = dispatched
    }

    var pillar: Pillar { Pillar(rawValue: pillarRaw) ?? .work }
    var isAlive: Bool { !dispatched && Date() < expiresAt && progress < requiredHits }
    var fractionDone: Double { Double(progress) / Double(max(1, requiredHits)) }
}
