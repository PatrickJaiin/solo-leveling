import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class QuestEngine {
    var lastLevelUp: RankSystem.LevelUpResult?
    var lastShadow: Shadow?
    var lastFragment: Fragment?
    var lastBossSpawned: BossEcho?
    var lastBossKilled: BossEcho?
    var isGenerating: Bool = false
    var lastGenerationError: String?

    private let claude: ClaudeAPIService
    private let gemini: GeminiAPIService
    private let notifications: NotificationService
    let takeovers: SystemTakeoverCenter

    init(claude: ClaudeAPIService, gemini: GeminiAPIService, notifications: NotificationService, takeovers: SystemTakeoverCenter) {
        self.claude = claude
        self.gemini = gemini
        self.notifications = notifications
        self.takeovers = takeovers
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
        var debtAccrued = 0
        let wasRestDay = (hunter.activeRestDayKey == yesterday)
        let mods = Modifiers.from(hunter)
        for q in yQuests {
            switch q.status {
            case .assigned:
                q.status = .missed
                missed += 1
                // Accrue XP debt for each missed quest (unless yesterday was a Sanctioned Rest).
                if !wasRestDay {
                    let raw = q.effectiveXP
                    let forgiven = Int(Double(raw) * mods.debtForgiveness)
                    debtAccrued += max(0, raw - forgiven)
                }
            case .completed:
                completed += 1
                xpEarned += q.effectiveXP
            case .missed:
                missed += 1
            }
        }
        if debtAccrued > 0 { hunter.xpDebt += debtAccrued }

        let total = yQuests.count
        let rate = total > 0 ? Double(completed) / Double(total) : 1.0
        // Penalty zone still triggers on poor performance for stricter quest tone + more quests,
        // but the XP multiplier has been removed — debt is the punishment now.
        let enterPenalty = !wasRestDay && total > 0 && rate < 0.5

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

        // 3. Update streak. Rest day preserves the streak unconditionally.
        if wasRestDay {
            // streak preserved as-is
        } else if completed > 0 {
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

        // Consider spawning a Boss Echo for chronically-weak pillars.
        if let echo = BossEchoService.considerSpawn(hunter: hunter, context: context) {
            lastBossSpawned = echo
            SystemSound.penalty.play()
            takeovers.post(.bossSpawn(echo))
            notifications.post(.alert,
                title: "[ ECHO MANIFESTED — \(echo.name.uppercased()) ]",
                body: "\(echo.flavor) Kill condition: \(echo.killCondition)")
        }

        // Take-over: announce daily quest issue.
        let issuedCount = (try? context.fetch(FetchDescriptor<Quest>(predicate: #Predicate { $0.dayKey == today })))?.count ?? 0
        takeovers.post(.questsIssued(count: issuedCount, isPenalty: hunter.inPenaltyZone))

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

        // Apply shadow XP bonuses (legacy — to be replaced by Boss Echoes).
        let shadows = (try? context.fetch(FetchDescriptor<Shadow>())) ?? []
        var bonus = 1.0
        for s in shadows where s.pillar == quest.pillar && s.bonusType == "xp_multiplier" {
            bonus += s.bonusValue
        }
        // Apply stat-driven Modifiers (each pillar has its own scaling stat).
        let mods = Modifiers.from(hunter)
        let pillarMult = mods.multiplier(for: quest.pillar)
        // Active Boss Echoes apply a debuff to their pillar.
        let bossDebuff = BossEchoService.activeDebuff(for: quest.pillar, context: context)
        let xp = Int(Double(quest.effectiveXP) * bonus * pillarMult * bossDebuff)
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

        // Shadow extraction check (legacy streak path — still works for manually-added recurring quests).
        if let shadow = ShadowExtractor.tryExtract(after: quest, context: context) {
            lastShadow = shadow
            SystemSound.shadowExtract.play()
            notifications.post(.alert,
                title: "[ SHADOW EXTRACTION ]",
                body: "A new shadow has joined your army: \(shadow.name).")
        }

        // Boss Echo hit registration. If we kill one, it becomes a Shadow (handled inside).
        let bossResult = BossEchoService.registerHit(quest: quest, hunter: hunter, context: context)
        if let killed = bossResult.killed {
            lastBossKilled = killed
            SystemSound.shadowExtract.play()
            takeovers.post(.bossKilled(killed))
            notifications.post(.alert,
                title: "[ ECHO DISPATCHED ]",
                body: "\(killed.name) collapses. The System adds it to your Shadow Army.")
        }

        // Variable-reward Fragment drop.
        if let f = FragmentService.roll(after: quest, hunter: hunter, context: context) {
            lastFragment = f
            takeovers.post(.fragmentDrop(f))
            notifications.post(.alert,
                title: "[ DROP — \(f.rarity.label) ]",
                body: "\(f.title) — \(f.detail)")
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

    // Completion is intentionally one-way. The System never takes back what it has granted —
    // and that prevents the user from spamming a tick on/off to multiply XP.

    // MARK: - Sanctioned Rest

    /// Can the Hunter invoke a Sanctioned Rest Day right now?
    func canInvokeRest(hunter: Hunter) -> Bool {
        let mods = Modifiers.from(hunter)
        guard let last = hunter.lastRestDayKey, let lastDate = DayKey.date(from: last) else { return true }
        let now = Date()
        let elapsed = Int(now.timeIntervalSince(lastDate) / 86400)
        return elapsed >= mods.restCooldownDays
    }

    func nextRestEligibleDayKey(hunter: Hunter) -> String? {
        let mods = Modifiers.from(hunter)
        guard let last = hunter.lastRestDayKey, let lastDate = DayKey.date(from: last) else { return nil }
        let eligible = Calendar.current.date(byAdding: .day, value: mods.restCooldownDays, to: lastDate) ?? lastDate
        return DayKey.key(for: eligible)
    }

    /// Invoke today as a Sanctioned Rest Day. No debt, no streak break, no penalty.
    func invokeRestDay(hunter: Hunter, context: ModelContext) {
        guard canInvokeRest(hunter: hunter) else { return }
        let today = DayKey.key()
        hunter.activeRestDayKey = today
        hunter.lastRestDayKey = today
        takeovers.post(.restDecreed())
        notifications.post(.alert,
            title: "[ REST DECREED ]",
            body: "The System withdraws for the day. No debt will be levied.")
        do { try context.save() } catch { lastGenerationError = "Save failed: \(error.localizedDescription)" }
    }

    // MARK: - Provider validation

    func ping(provider: AIProvider) async throws {
        _ = try await generator(for: provider).ping()
    }

    /// Wipe today's incomplete quests and regenerate the set. Completed quests are preserved
    /// (and their XP already counts) — only `.assigned` and `.missed` get replaced.
    func reissueToday(hunter: Hunter, context: ModelContext, useAI: Bool, provider: AIProvider) async {
        let today = DayKey.key()
        let existing = (try? context.fetch(FetchDescriptor<Quest>(predicate: #Predicate { $0.dayKey == today }))) ?? []
        for q in existing where q.status != .completed {
            context.delete(q)
        }
        let penalty = hunter.inPenaltyZone
        await generateQuests(for: today, hunter: hunter, context: context, useAI: useAI, provider: provider, forcePenalty: penalty)
        do { try context.save() } catch { lastGenerationError = "Save failed: \(error.localizedDescription)" }
    }

    /// User-proposed quest. AI scores it against the Hunter's baseline, then we insert
    /// it into today's quest list. Throws if the chosen provider fails — caller decides
    /// whether to fall back to a sensible default or surface the error.
    func addManualQuest(title: String, detail: String, hunter: Hunter,
                         context: ModelContext, provider: AIProvider) async throws -> Quest {
        let tpl = try await generator(for: provider).scoreQuest(title: title, detail: detail, hunter: hunter)
        let q = Quest(title: tpl.title,
                      detail: tpl.detail,
                      pillar: tpl.pillar,
                      difficulty: tpl.difficulty,
                      baseXP: tpl.baseXP,
                      statReward: tpl.statReward,
                      dayKey: DayKey.key(),
                      autoCompletable: tpl.autoCompletable,
                      source: provider.rawValue)
        context.insert(q)
        return q
    }
}
