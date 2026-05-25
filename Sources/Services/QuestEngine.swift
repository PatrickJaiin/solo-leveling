import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class QuestEngine {
    var lastLevelUp: RankSystem.LevelUpResult?
    var lastShadow: Shadow?
    var isGenerating: Bool = false
    var lastGenerationError: String?

    private let claude: ClaudeAPIService
    private let gemini: GeminiAPIService
    private let notifications: NotificationService

    init(claude: ClaudeAPIService, gemini: GeminiAPIService, notifications: NotificationService) {
        self.claude = claude
        self.gemini = gemini
        self.notifications = notifications
    }

    private func generator(for provider: AIProvider) -> QuestGenerator {
        switch provider {
        case .claude: claude
        case .gemini: gemini
        }
    }

    // MARK: - Daily flow

    /// Returns true if quests for today haven't been generated yet.
    func needsDailyReset(hunter: Hunter) -> Bool {
        hunter.lastQuestDayKey != DayKey.key()
    }

    /// Performs the daily reset: closes out yesterday, computes penalty, generates today's quests.
    /// Idempotent — safe to call multiple times the same day; quests are generated once.
    func performDailyReset(hunter: Hunter, context: ModelContext, useAI: Bool, provider: AIProvider) async {
        let today = DayKey.key()
        let yesterday = DayKey.yesterday()

        // Idempotency guard: if today's quests already exist, only mark the reset done and return.
        let existingToday = (try? context.fetch(FetchDescriptor<Quest>(predicate: #Predicate { $0.dayKey == today }))) ?? []
        if !existingToday.isEmpty {
            hunter.lastQuestDayKey = today
            do { try context.save() } catch { lastGenerationError = "Save failed: \(error.localizedDescription)" }
            return
        }

        // 1. Close out yesterday — anything still "assigned" becomes "missed".
        let yQuests = (try? context.fetch(FetchDescriptor<Quest>(predicate: #Predicate { $0.dayKey == yesterday }))) ?? []
        var completed = 0, missed = 0, xpEarned = 0
        for q in yQuests {
            switch q.status {
            case .assigned:
                q.status = .missed
                missed += 1
            case .completed:
                completed += 1
                xpEarned += q.effectiveXP
            case .missed:
                missed += 1
            }
        }

        let total = yQuests.count
        let rate = total > 0 ? Double(completed) / Double(total) : 1.0
        let enterPenalty = total > 0 && rate < 0.5

        // 2. Update daily log for yesterday.
        if total > 0 {
            let existing = (try? context.fetch(FetchDescriptor<DailyLog>(predicate: #Predicate { $0.dayKey == yesterday })))?.first
            if let existing {
                existing.questsAssigned = total
                existing.questsCompleted = completed
                existing.questsMissed = missed
                existing.xpEarned = xpEarned
                existing.enteredPenalty = enterPenalty
            } else if let yDate = DayKey.date(from: yesterday) {
                context.insert(DailyLog(dayKey: yesterday, date: yDate,
                                         questsAssigned: total, questsCompleted: completed,
                                         questsMissed: missed, xpEarned: xpEarned,
                                         enteredPenalty: enterPenalty))
            }
        }

        // 3. Update streak.
        if completed > 0 {
            hunter.dayStreak += 1
        } else if total > 0 {
            hunter.dayStreak = 0
        }
        hunter.inPenaltyZone = enterPenalty

        // 4. Generate today's quests. Snapshot penalty flag so an await suspension can't desync.
        let penaltyForToday = hunter.inPenaltyZone
        await generateQuests(for: today, hunter: hunter, context: context, useAI: useAI, provider: provider, forcePenalty: penaltyForToday)

        hunter.lastQuestDayKey = today
        do { try context.save() } catch { lastGenerationError = "Save failed: \(error.localizedDescription)" }

        // 5. Notify.
        let dayLabel = DayKey.isSunday() ? "Weekly Dungeon Day" : "Daily Quests Issued"
        if hunter.inPenaltyZone {
            notifications.post(.alert,
                title: "[ PENALTY ZONE ]",
                body: "You failed to complete yesterday's quests. The System has assigned a harder set.")
        } else {
            notifications.post(.alert,
                title: "[ \(dayLabel.uppercased()) ]",
                body: "Hunter \(hunter.name) — open your quest log.")
        }
    }

    /// Generates the day's quests via the chosen AI provider, falling back to templates on any failure.
    func generateQuests(for dayKey: String, hunter: Hunter, context: ModelContext, useAI: Bool, provider: AIProvider, forcePenalty: Bool? = nil) async {
        isGenerating = true
        defer { isGenerating = false }

        // Always include weekly dungeon quest on Sundays.
        let isSunday = DayKey.date(from: dayKey).map { DayKey.isSunday($0) } ?? false
        let isPenalty = forcePenalty ?? hunter.inPenaltyZone
        let baseCount = isPenalty ? 7 : 5

        var generated: [QuestTemplate] = []

        if useAI {
            do {
                generated = try await generator(for: provider).generateDailyQuests(hunter: hunter,
                                                                                    isPenalty: isPenalty,
                                                                                    isSunday: isSunday,
                                                                                    count: baseCount)
                lastGenerationError = nil
            } catch {
                lastGenerationError = "\(provider.label) generation failed: \(error.localizedDescription). Using templates."
                generated = QuestTemplates.dailySet(count: baseCount)
            }
        } else {
            generated = QuestTemplates.dailySet(count: baseCount)
        }

        for tpl in generated.prefix(baseCount) {
            let q = Quest(title: tpl.title, detail: tpl.detail, pillar: tpl.pillar,
                          difficulty: tpl.difficulty, baseXP: tpl.baseXP,
                          statReward: tpl.statReward, dayKey: dayKey,
                          isPenalty: isPenalty,
                          autoCompletable: tpl.autoCompletable,
                          source: useAI ? provider.rawValue : "template")
            context.insert(q)
        }

        if isSunday {
            // Weekly Dungeon — a single high-XP cross-pillar challenge.
            let dungeon = Quest(
                title: "Weekly Dungeon: Reflect + Plan + Move",
                detail: "Write a one-page weekly review, set 3 goals for next week, and complete a 45-minute workout.",
                pillar: .mental,
                difficulty: .hard,
                baseXP: 200,
                statReward: .sen,
                dayKey: dayKey,
                isDungeon: true,
                source: "dungeon")
            context.insert(dungeon)
        }
    }

    // MARK: - Quest completion

    func complete(quest: Quest, hunter: Hunter, context: ModelContext) {
        guard quest.status == .assigned else { return }
        quest.status = .completed
        quest.completedAt = Date()
        hunter.lifetimeQuestsCompleted += 1

        // Apply shadow XP bonuses.
        let shadows = (try? context.fetch(FetchDescriptor<Shadow>())) ?? []
        var bonus = 1.0
        for s in shadows where s.pillar == quest.pillar && s.bonusType == "xp_multiplier" {
            bonus += s.bonusValue
        }
        let xp = Int(Double(quest.effectiveXP) * bonus)
        let result = RankSystem.grantXP(xp, to: hunter)
        if result.didLevelUp {
            lastLevelUp = result
            hunter.title = RankSystem.suggestedTitle(for: hunter)
            SystemSound.levelUp.play()
            notifications.post(.alert,
                title: "[ LEVEL UP ]",
                body: "Hunter \(hunter.name) reached level \(hunter.level)" +
                      (result.rankChangedTo != nil ? " — promoted to \(result.rankChangedTo!.displayName)-Rank." : "."))
        } else {
            SystemSound.questComplete.play()
        }
        hunter.addStat(quest.statReward, quest.statRewardAmount)

        // Shadow extraction check.
        if let shadow = ShadowExtractor.tryExtract(after: quest, context: context) {
            lastShadow = shadow
            SystemSound.shadowExtract.play()
            notifications.post(.alert,
                title: "[ SHADOW EXTRACTION ]",
                body: "A new shadow has joined your army: \(shadow.name).")
        }

        // Penalty cleared? Require at least one quest assigned and 50%+ done.
        if hunter.inPenaltyZone {
            let today = DayKey.key()
            let todayQuests = (try? context.fetch(FetchDescriptor<Quest>(predicate: #Predicate { $0.dayKey == today }))) ?? []
            let done = todayQuests.filter { $0.status == .completed }.count
            if !todayQuests.isEmpty && done * 2 >= todayQuests.count {
                hunter.inPenaltyZone = false
                notifications.post(.alert,
                    title: "[ PENALTY CLEARED ]",
                    body: "The System has restored your rank progression.")
            }
        }
    }

    func uncomplete(quest: Quest, hunter: Hunter, context _: ModelContext) {
        guard quest.status == .completed else { return }
        quest.status = .assigned
        quest.completedAt = nil
        hunter.lifetimeQuestsCompleted = max(0, hunter.lifetimeQuestsCompleted - 1)
        // Refund is intentionally lossy — XP/stats stay. Solo Leveling never gives back what the System paid.
    }
}
