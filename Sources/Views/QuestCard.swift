import SwiftUI

struct QuestCard: View {
    let quest: Quest
    var onComplete: () -> Void

    var body: some View {
        SystemPanel(tint: cardTint, notch: 10, padding: 14) {
            HStack(alignment: .top, spacing: 14) {
                completeButton
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        SystemTag(text: quest.pillar.label, tint: quest.pillar.tint)
                        SystemTag(text: "DIFF \(quest.difficulty.label)", tint: difficultyTint)
                        if quest.isPenalty { SystemTag(text: "PENALTY", tint: Theme.danger) }
                        if quest.isDungeon { SystemTag(text: "DUNGEON", tint: Theme.systemGold) }
                        if quest.autoCompletable { SystemTag(text: "AUTO", tint: Theme.success) }
                        if quest.source == "claude" { SystemTag(text: "CLAUDE", tint: Theme.systemCyan) }
                        if quest.source == "gemini" { SystemTag(text: "GEMINI", tint: Theme.systemCyan) }
                        Spacer()
                        Text("+\(quest.effectiveXP) XP")
                            .font(Typography.value)
                            .foregroundStyle(Theme.systemGold)
                            .glow(Theme.systemGold, radius: 3, intensity: 0.4)
                    }
                    Text(quest.title)
                        .font(Typography.mono(16, weight: .bold))
                        .foregroundStyle(.white)
                        .strikethrough(quest.status == .completed)
                    if !quest.detail.isEmpty {
                        Text(quest.detail)
                            .font(Typography.body)
                            .foregroundStyle(Theme.dim)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: quest.pillar.systemImage)
                            .foregroundStyle(quest.pillar.tint)
                        Text("+1 \(quest.statReward.label)")
                            .font(Typography.systemTag)
                            .foregroundStyle(quest.pillar.tint)
                        Spacer()
                        Text("ISSUED \(quest.dayKey)")
                            .font(Typography.systemTag)
                            .foregroundStyle(Theme.dim.opacity(0.7))
                    }
                }
            }
        }
        .opacity(quest.status == .completed ? 0.55 : 1.0)
    }

    private var cardTint: Color {
        switch quest.status {
        case .completed: Theme.success
        case .missed: Theme.danger
        case .assigned: quest.pillar.tint
        }
    }

    private var difficultyTint: Color {
        switch quest.difficulty {
        case .easy: Theme.success
        case .normal: Theme.systemBlue
        case .hard: Theme.systemGold
        case .extreme: Theme.danger
        }
    }

    @ViewBuilder
    private var completeButton: some View {
        Button {
            if quest.status == .assigned { onComplete() }
        } label: {
            ZStack {
                NotchedRectangle(notch: 6)
                    .fill(cardTint.opacity(quest.status == .completed ? 0.4 : 0.05))
                    .overlay(NotchedRectangle(notch: 6).stroke(cardTint, lineWidth: 1.4))
                    .frame(width: 30, height: 30)
                if quest.status == .completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
            .glow(cardTint, radius: 4, intensity: 0.6)
        }
        .buttonStyle(.plain)
        .disabled(quest.status != .assigned)
    }
}
