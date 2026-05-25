import Foundation

/// Fallback quest templates when AI generation is unavailable.
struct QuestTemplate {
    let title: String
    let detail: String
    let pillar: Pillar
    let difficulty: Difficulty
    let baseXP: Int
    let statReward: StatKey
    let autoCompletable: Bool
}

enum QuestTemplates {
    static let all: [QuestTemplate] = [
        // Work
        .init(title: "Complete one deep work block (90 min)", detail: "No notifications. One task only.",
              pillar: .work, difficulty: .normal, baseXP: 70, statReward: .int, autoCompletable: false),
        .init(title: "Inbox to zero", detail: "Archive, reply, or defer every email.",
              pillar: .work, difficulty: .easy, baseXP: 40, statReward: .int, autoCompletable: false),
        .init(title: "Ship something today", detail: "Merge a PR, send a doc, or close a ticket.",
              pillar: .work, difficulty: .hard, baseXP: 100, statReward: .int, autoCompletable: false),
        .init(title: "Plan tomorrow before EOD", detail: "Write the top 3 tasks for tomorrow.",
              pillar: .work, difficulty: .easy, baseXP: 35, statReward: .sen, autoCompletable: false),

        // Fitness
        .init(title: "Hit 10,000 steps", detail: "Walk it off.",
              pillar: .fitness, difficulty: .normal, baseXP: 60, statReward: .agi, autoCompletable: true),
        .init(title: "100 push-ups (any split)", detail: "Sets of 10, 20, 25 — whatever works.",
              pillar: .fitness, difficulty: .normal, baseXP: 60, statReward: .str, autoCompletable: false),
        .init(title: "30-minute workout", detail: "Anything that gets the heart rate up.",
              pillar: .fitness, difficulty: .hard, baseXP: 90, statReward: .str, autoCompletable: true),
        .init(title: "Stretch / mobility (10 min)", detail: "Pick three areas. Move them.",
              pillar: .fitness, difficulty: .easy, baseXP: 35, statReward: .agi, autoCompletable: false),

        // Mental
        .init(title: "10-minute meditation", detail: "Just sit. Just breathe.",
              pillar: .mental, difficulty: .easy, baseXP: 40, statReward: .sen, autoCompletable: false),
        .init(title: "Journal one page", detail: "What happened. What you felt. What's next.",
              pillar: .mental, difficulty: .normal, baseXP: 55, statReward: .sen, autoCompletable: false),
        .init(title: "No social media before noon", detail: "Stay out of the feed.",
              pillar: .mental, difficulty: .normal, baseXP: 60, statReward: .sen, autoCompletable: false),
        .init(title: "Read 20 pages", detail: "Book, paper, longform — not a feed.",
              pillar: .mental, difficulty: .normal, baseXP: 55, statReward: .int, autoCompletable: false),

        // Vitality
        .init(title: "Drink 3L of water", detail: "Refill, sip, repeat.",
              pillar: .vitality, difficulty: .easy, baseXP: 35, statReward: .vit, autoCompletable: false),
        .init(title: "Sleep 7+ hours tonight", detail: "Lights out. No screens past the line.",
              pillar: .vitality, difficulty: .normal, baseXP: 70, statReward: .vit, autoCompletable: false),
        .init(title: "No screens 60 min before bed", detail: "Phone down. Lights dim.",
              pillar: .vitality, difficulty: .normal, baseXP: 50, statReward: .vit, autoCompletable: false),
        .init(title: "Eat one real meal (no skipping)", detail: "Protein + veg + carb.",
              pillar: .vitality, difficulty: .easy, baseXP: 30, statReward: .vit, autoCompletable: false),
    ]

    static func dailySet(count: Int = 5) -> [QuestTemplate] {
        var byPillar: [Pillar: [QuestTemplate]] = [:]
        for t in all { byPillar[t.pillar, default: []].append(t) }
        var result: [QuestTemplate] = []
        for pillar in Pillar.allCases {
            if let pick = byPillar[pillar]?.randomElement() { result.append(pick) }
        }
        let extras = all.shuffled().filter { tpl in !result.contains(where: { $0.title == tpl.title }) }
        while result.count < count, let next = extras.dropFirst(result.count - 4).first {
            if !result.contains(where: { $0.title == next.title }) { result.append(next) }
        }
        return result
    }
}
