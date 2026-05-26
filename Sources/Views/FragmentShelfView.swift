import SwiftUI
import SwiftData

/// Recent-drops shelf. Lives on the Stats tab. Variable-reward loot card collection.
struct FragmentShelfView: View {
    @Query(sort: \Fragment.droppedAt, order: .reverse) private var fragments: [Fragment]

    var body: some View {
        SystemPanel("Fragments", tint: Theme.systemCyan) {
            if fragments.isEmpty {
                Text("No fragments yet. The System drops shards as you complete quests — most are common, some are not.")
                    .font(Typography.body).foregroundStyle(Theme.dim)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(fragments.prefix(20)) { f in
                        HStack(alignment: .top, spacing: 10) {
                            SystemTag(text: f.rarity.label, tint: f.rarity.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.title)
                                    .font(Typography.body.weight(.bold))
                                    .foregroundStyle(f.rarity.tint)
                                Text(f.detail)
                                    .font(Typography.systemTag.weight(.regular))
                                    .foregroundStyle(.white.opacity(0.85))
                                Text("\(f.sourceDayKey) · from “\(f.sourceQuestTitle)”")
                                    .font(Typography.systemTag).foregroundStyle(Theme.dim)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}
