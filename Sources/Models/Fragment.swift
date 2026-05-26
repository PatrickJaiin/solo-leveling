import Foundation
import SwiftData
import SwiftUI

/// Variable-reward drops. Awarded probabilistically on quest completion. Pure flavor +
/// occasional small bonus — what hooks people on Finch / Animal Crossing-style loops.
@Model
final class Fragment {
    @Attribute(.unique) var id: UUID
    var title: String           // "Cracked Mana Stone", "Page from a Hunter's Journal", etc.
    var detail: String          // 1-2 sentence flavor text (AI-written, in System voice)
    var rarityRaw: String       // common / uncommon / rare / epic
    var pillarRaw: String?      // optional pillar association (matches the quest that dropped it)
    var droppedAt: Date
    /// dayKey of the quest that dropped this fragment.
    var sourceDayKey: String
    /// Title of the quest that dropped it (for the journal feel).
    var sourceQuestTitle: String

    init(id: UUID = UUID(),
         title: String,
         detail: String,
         rarity: Rarity,
         pillar: Pillar?,
         droppedAt: Date = Date(),
         sourceDayKey: String,
         sourceQuestTitle: String) {
        self.id = id
        self.title = title
        self.detail = detail
        self.rarityRaw = rarity.rawValue
        self.pillarRaw = pillar?.rawValue
        self.droppedAt = droppedAt
        self.sourceDayKey = sourceDayKey
        self.sourceQuestTitle = sourceQuestTitle
    }

    var rarity: Rarity { Rarity(rawValue: rarityRaw) ?? .common }
    var pillar: Pillar? { pillarRaw.flatMap { Pillar(rawValue: $0) } }
}

enum Rarity: String, Codable, CaseIterable, Identifiable {
    case common, uncommon, rare, epic

    var id: String { rawValue }
    var label: String { rawValue.uppercased() }
    var weight: Double {
        switch self {
        case .common: 0.55
        case .uncommon: 0.30
        case .rare: 0.12
        case .epic: 0.03
        }
    }

    var tint: Color {
        switch self {
        case .common: Color(white: 0.7)
        case .uncommon: Color(red: 0.55, green: 0.95, blue: 1.0)
        case .rare: Color(red: 0.78, green: 0.55, blue: 1.0)
        case .epic: Color(red: 1.0, green: 0.84, blue: 0.45)
        }
    }
}
