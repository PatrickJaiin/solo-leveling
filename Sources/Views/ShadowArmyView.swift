import SwiftUI
import SwiftData

struct ShadowArmyView: View {
    @Query(sort: \Shadow.extractedAt, order: .reverse) private var shadows: [Shadow]

    let columns = [GridItem(.adaptive(minimum: 220), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                SystemPanel("Shadow Army", tint: Theme.systemCyan, notch: 14) {
                    Text("Habits sustained for \(ShadowExtractor.extractionThreshold)+ consecutive days are extracted as Shadows. Each Shadow grants a passive XP bonus in its pillar.")
                        .font(Typography.body).foregroundStyle(Theme.dim)
                }
                if shadows.isEmpty {
                    SystemPanel(tint: Theme.dim) {
                        Text("No shadows yet. Sustain a daily quest for \(ShadowExtractor.extractionThreshold) days to extract one.")
                            .font(Typography.body).foregroundStyle(Theme.dim)
                    }
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(shadows) { s in ShadowCard(shadow: s) }
                    }
                }
            }
            .padding(20)
        }
    }
}

private struct ShadowCard: View {
    let shadow: Shadow
    var body: some View {
        SystemPanel(tint: shadow.pillar.tint, notch: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: shadow.pillar.systemImage).foregroundStyle(shadow.pillar.tint)
                    Text(shadow.name).font(Typography.mono(15, weight: .black)).foregroundStyle(.white)
                }
                Text("Source: \(shadow.sourceQuestTitle)")
                    .font(Typography.systemTag).foregroundStyle(Theme.dim)
                HStack {
                    SystemTag(text: shadow.pillar.label, tint: shadow.pillar.tint)
                    SystemTag(text: "+\(Int(shadow.bonusValue * 100))% XP", tint: Theme.systemGold)
                }
                Text("Extracted from a \(shadow.sourceStreak)-day streak")
                    .font(Typography.systemTag).foregroundStyle(Theme.dim)
            }
        }
    }
}
