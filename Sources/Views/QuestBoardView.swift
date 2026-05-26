import SwiftUI
import SwiftData

struct QuestBoardView: View {
    @Environment(\.modelContext) private var context
    @Environment(QuestEngine.self) private var engine
    @Environment(AppSettings.self) private var settings

    let hunter: Hunter
    @State private var encounters: [EventKitService.ScheduledEncounter] = []
    let eventKit: EventKitService
    let healthKit: HealthKitService

    @Query(sort: \Quest.assignedAt, order: .forward) private var allQuests: [Quest]
    @Query private var bossEchoes: [BossEcho]

    var activeEcho: BossEcho? { bossEchoes.first(where: { $0.isAlive }) }

    /// Bumped at midnight; reading it in `body` is what makes SwiftUI re-evaluate `today`.
    @State private var dayTick: Int = 0

    // Manual add-quest form state
    @State private var newQuestTitle: String = ""
    @State private var newQuestDetail: String = ""
    @State private var addingQuest: Bool = false
    @State private var addError: String?

    var today: String { _ = dayTick; return DayKey.key() }
    var todayQuests: [Quest] {
        _ = dayTick
        return allQuests.filter { $0.dayKey == today }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if hunter.inPenaltyZone { PenaltyBanner() }
                if let echo = activeEcho { BossEchoBanner(echo: echo) }

                if engine.isGenerating {
                    SystemPanel(tint: Theme.systemCyan) {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text("THE SYSTEM IS GENERATING TODAY'S QUESTS…")
                                .font(Typography.body).foregroundStyle(Theme.systemCyan)
                        }
                    }
                }

                if let err = engine.lastGenerationError {
                    SystemPanel("Notice", tint: Theme.danger) {
                        Text(err).font(Typography.body).foregroundStyle(Theme.danger)
                    }
                }

                SystemPanel("Today — \(today)", tint: Theme.systemBlue) {
                    HStack {
                        Spacer()
                        Button {
                            Task { await engine.reissueToday(hunter: hunter, context: context, useAI: settings.useAI, provider: settings.aiProvider) }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("REISSUE")
                            }
                            .font(Typography.systemTag)
                            .foregroundStyle(Theme.systemCyan)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(NotchedRectangle(notch: 4).fill(Theme.systemCyan.opacity(0.08)))
                            .overlay(NotchedRectangle(notch: 4).stroke(Theme.systemCyan, lineWidth: 1))
                            .contentShape(NotchedRectangle(notch: 4))
                        }
                        .buttonStyle(.plain)
                        .disabled(engine.isGenerating)
                    }
                    if todayQuests.isEmpty {
                        VStack(spacing: 8) {
                            Text("No quests yet.").font(Typography.body).foregroundStyle(Theme.dim)
                            Button {
                                Task { await engine.performDailyReset(hunter: hunter, context: context, useAI: settings.useAI, provider: settings.aiProvider) }
                            } label: {
                                Text("[ ISSUE TODAY'S QUESTS ]")
                                    .font(Typography.systemTag)
                                    .foregroundStyle(Theme.systemCyan)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(NotchedRectangle(notch: 4).fill(Theme.systemCyan.opacity(0.08)))
                                    .overlay(NotchedRectangle(notch: 4).stroke(Theme.systemCyan, lineWidth: 1))
                                    .contentShape(NotchedRectangle(notch: 4))
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        VStack(spacing: 10) {
                            ForEach(todayQuests) { q in
                                QuestCard(quest: q,
                                          onComplete: { engine.complete(quest: q, hunter: hunter, context: context) })
                            }
                        }
                    }
                }

                SystemPanel("Add Your Own Quest", tint: Theme.systemGold) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Type a task. The AI will score pillar / difficulty / XP using your baseline.")
                            .font(Typography.systemTag).foregroundStyle(Theme.dim)
                        TextField("e.g. Finish design review for the auth flow", text: $newQuestTitle)
                            .textFieldStyle(.plain)
                            .font(Typography.body).foregroundStyle(.white)
                            .padding(8)
                            .background(NotchedRectangle(notch: 4).stroke(Theme.systemGold.opacity(0.4), lineWidth: 1))
                        TextField("Detail (optional)", text: $newQuestDetail)
                            .textFieldStyle(.plain)
                            .font(Typography.body).foregroundStyle(.white)
                            .padding(8)
                            .background(NotchedRectangle(notch: 4).stroke(Theme.systemGold.opacity(0.4), lineWidth: 1))
                        HStack(spacing: 10) {
                            Button {
                                Task { await addManualQuest() }
                            } label: {
                                HStack(spacing: 6) {
                                    if addingQuest { ProgressView().controlSize(.mini) }
                                    Text(addingQuest ? "Scoring…" : "[ ADD QUEST ]")
                                        .font(Typography.systemTag).foregroundStyle(Theme.systemGold)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(NotchedRectangle(notch: 4).fill(Theme.systemGold.opacity(0.08)))
                                        .overlay(NotchedRectangle(notch: 4).stroke(Theme.systemGold, lineWidth: 1))
                                        .contentShape(NotchedRectangle(notch: 4))
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(addingQuest || newQuestTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            if !settings.useAI {
                                Text("⚠︎ Turn on AI in Settings — scoring needs the API.")
                                    .font(Typography.systemTag).foregroundStyle(Theme.danger)
                            }
                        }
                        if let addError {
                            Text(addError).font(Typography.systemTag).foregroundStyle(Theme.danger)
                        }
                    }
                }

                if !encounters.isEmpty {
                    SystemPanel("Scheduled Encounters", tint: Theme.systemGold) {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(encounters) { ev in
                                HStack(spacing: 10) {
                                    Text(ev.start.formatted(date: .omitted, time: .shortened))
                                        .font(Typography.body).foregroundStyle(Theme.systemGold)
                                        .frame(width: 60, alignment: .leading)
                                    Text(ev.title).font(Typography.body).foregroundStyle(.white)
                                    Spacer()
                                    Text("\(Int(ev.end.timeIntervalSince(ev.start) / 60))m")
                                        .font(Typography.systemTag).foregroundStyle(Theme.dim)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .task(id: dayTick) {
            if engine.needsDailyReset(hunter: hunter) {
                await engine.performDailyReset(hunter: hunter, context: context, useAI: settings.useAI, provider: settings.aiProvider)
            }
            if settings.useCalendar { encounters = eventKit.todayEvents() } else { encounters = [] }
            if settings.useHealthKit { await autoCompleteFromHealth() }
        }
        .onChange(of: settings.useCalendar) { _, on in
            encounters = on ? eventKit.todayEvents() : []
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.NSCalendarDayChanged)) { _ in
            dayTick &+= 1
        }
    }

    private func addManualQuest() async {
        let title = newQuestTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        addingQuest = true
        addError = nil
        defer { addingQuest = false }
        do {
            _ = try await engine.addManualQuest(title: title,
                                                 detail: newQuestDetail.trimmingCharacters(in: .whitespacesAndNewlines),
                                                 hunter: hunter,
                                                 context: context,
                                                 provider: settings.aiProvider)
            newQuestTitle = ""
            newQuestDetail = ""
        } catch {
            addError = "\(settings.aiProvider.label) couldn't score this quest: \(error.localizedDescription)"
        }
    }

    /// Auto-complete fitness quests when HealthKit shows steps/workouts have been done.
    private func autoCompleteFromHealth() async {
        let summary = await healthKit.todaySummary()
        for q in todayQuests where q.autoCompletable && q.status == .assigned {
            let lower = q.title.lowercased()
            if lower.contains("step") && summary.steps >= 10000 {
                engine.complete(quest: q, hunter: hunter, context: context)
            } else if (lower.contains("workout") || lower.contains("training")) && summary.workoutMinutes >= 30 {
                engine.complete(quest: q, hunter: hunter, context: context)
            }
        }
    }
}
