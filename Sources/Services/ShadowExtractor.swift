import Foundation
import SwiftData

enum ShadowExtractor {
    /// Streak length at which a shadow can be extracted from a quest title.
    static let extractionThreshold = 7

    /// After completing `quest`, check if its title has been completed `extractionThreshold` days
    /// in a row and, if so, create and persist a Shadow.
    static func tryExtract(after quest: Quest, context: ModelContext) -> Shadow? {
        let title = quest.title

        // Don't double-extract from the same title.
        let existing = (try? context.fetch(FetchDescriptor<Shadow>(predicate: #Predicate { $0.sourceQuestTitle == title }))) ?? []
        if !existing.isEmpty { return nil }

        // Count consecutive completed days ending today.
        let all = (try? context.fetch(FetchDescriptor<Quest>(predicate: #Predicate { $0.title == title && $0.statusRaw == "completed" }))) ?? []
        let dayKeys = Set(all.map { $0.dayKey })

        var streak = 0
        var cursor = Date()
        while dayKeys.contains(DayKey.key(for: cursor)) {
            streak += 1
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }

        guard streak >= extractionThreshold else { return nil }

        let bonusValue = min(0.25, 0.05 * Double(streak / extractionThreshold))
        let shadow = Shadow(name: shadowName(for: quest.pillar, streak: streak),
                            sourceQuestTitle: title,
                            pillar: quest.pillar,
                            bonusType: "xp_multiplier",
                            bonusValue: bonusValue,
                            sourceStreak: streak)
        context.insert(shadow)
        return shadow
    }

    private static let names: [Pillar: [String]] = [
        .work: ["Iron-Scribe", "Codex", "Tessera", "Logos", "Cipher"],
        .fitness: ["Ironfang", "Sprinthound", "Atlas", "Bjorn", "Beru"],
        .mental: ["Stillwatch", "Quietmind", "Igris", "Lumen", "Tacit"],
        .vitality: ["Wellspring", "Verdant", "Tank", "Pulse", "Vesper"]
    ]

    private static func shadowName(for pillar: Pillar, streak: Int) -> String {
        let pool = names[pillar] ?? ["Wraith"]
        let base = pool.randomElement() ?? "Wraith"
        return "\(base) (Lv. \(max(1, streak / 7)))"
    }
}
