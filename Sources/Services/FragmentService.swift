import Foundation
import SwiftData

/// Variable-reward drop service. Each completed quest rolls for a Fragment.
/// Drop rate intentionally low (~28%) so it stays surprising.
@MainActor
enum FragmentService {
    static let dropChance: Double = 0.28

    /// Roll a fragment for the given completed quest. Returns nil if no drop this time.
    static func roll(after quest: Quest, hunter: Hunter, context: ModelContext) -> Fragment? {
        guard Double.random(in: 0..<1) < dropChance else { return nil }
        let rarity = rollRarity()
        let (title, detail) = flavor(for: quest, rarity: rarity)
        let f = Fragment(title: title,
                         detail: detail,
                         rarity: rarity,
                         pillar: quest.pillar,
                         sourceDayKey: quest.dayKey,
                         sourceQuestTitle: quest.title)
        context.insert(f)
        return f
    }

    private static func rollRarity() -> Rarity {
        let r = Double.random(in: 0..<1)
        var acc = 0.0
        for rarity in Rarity.allCases {
            acc += rarity.weight
            if r < acc { return rarity }
        }
        return .common
    }

    // Template flavor pool. AI-generated flavor can replace this later; templates keep things
    // free and instant. Keyed by pillar + rarity.
    private static func flavor(for quest: Quest, rarity: Rarity) -> (String, String) {
        let pool = templatePool[quest.pillar] ?? templatePool[.work]!
        let bucket = pool[rarity] ?? pool[.common]!
        let pair = bucket.randomElement() ?? ("Mana Fragment", "A shard from the System's memory.")
        return pair
    }

    private static let templatePool: [Pillar: [Rarity: [(String, String)]]] = [
        .work: [
            .common: [
                ("Cracked Logic Stone", "Mundane. The System logs your effort, nothing more."),
                ("Half-Formed Idea", "A residue of focused work. May yet sharpen.")
            ],
            .uncommon: [
                ("Sealed Scroll", "A line of code that explains itself. Rare."),
                ("Memory Fragment — Deep Work", "Briefly, the Hunter could not be reached. The System took note.")
            ],
            .rare: [
                ("Codex of the Diligent", "A page that compounds. You will not feel its weight for a year.")
            ],
            .epic: [
                ("Sigil of the Architect", "What you built today, others will build on. A piece of the System retains it.")
            ]
        ],
        .fitness: [
            .common: [
                ("Damp Bandage", "Sweat is interest paid on the body's loan."),
                ("Calcified Breath", "The lungs remember.")
            ],
            .uncommon: [
                ("Iron Pebble", "Heavier than it looks. Carry it forward."),
                ("Memory Fragment — Stride", "A pace settled in. The shadow approves.")
            ],
            .rare: [
                ("Tonic of the Unbroken", "One day of pain bought ten of capacity.")
            ],
            .epic: [
                ("Heart of the Hunter", "Pulse that does not flinch. Engrave this day.")
            ]
        ],
        .mental: [
            .common: [
                ("Quiet Stone", "It hummed for ten minutes. You did not interrupt it."),
                ("Folded Page", "Today's thought has been kept.")
            ],
            .uncommon: [
                ("Lantern Glass", "Catches small flames before they spread."),
                ("Memory Fragment — Stillness", "A minute the System could not bill.")
            ],
            .rare: [
                ("Charm of Quiet Hours", "It is heavier the longer you carry it.")
            ],
            .epic: [
                ("Crown of the Witness", "You watched yourself today without flinching. Few do.")
            ]
        ],
        .vitality: [
            .common: [
                ("Vial of Sleep", "Eight hours. Sealed and witnessed."),
                ("Bread Crust", "Calories paid. The day stands.")
            ],
            .uncommon: [
                ("Hearth Token", "Warm. Reusable. Reissued tomorrow."),
                ("Memory Fragment — Repose", "The body relaxed enough to dream.")
            ],
            .rare: [
                ("Elixir of the Restored", "Recovery, distilled.")
            ],
            .epic: [
                ("Pillar of Recovery", "Without you tending this, none of the others stood.")
            ]
        ]
    ]
}
