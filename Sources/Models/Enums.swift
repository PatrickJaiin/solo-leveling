import Foundation
import SwiftUI

enum Pillar: String, Codable, CaseIterable, Identifiable {
    case work
    case fitness
    case mental
    case vitality

    var id: String { rawValue }

    var label: String {
        switch self {
        case .work: "Work"
        case .fitness: "Fitness"
        case .mental: "Mental"
        case .vitality: "Vitality"
        }
    }

    var systemImage: String {
        switch self {
        case .work: "terminal.fill"
        case .fitness: "figure.run"
        case .mental: "brain.head.profile"
        case .vitality: "bolt.heart.fill"
        }
    }

    var tint: Color {
        switch self {
        case .work: Color(red: 0.36, green: 0.78, blue: 1.0)
        case .fitness: Color(red: 1.0, green: 0.45, blue: 0.45)
        case .mental: Color(red: 0.78, green: 0.55, blue: 1.0)
        case .vitality: Color(red: 0.45, green: 1.0, blue: 0.78)
        }
    }

    var primaryStat: StatKey {
        switch self {
        case .work: .int
        case .fitness: .str
        case .mental: .sen
        case .vitality: .vit
        }
    }
}

enum StatKey: String, Codable, CaseIterable, Identifiable {
    case str, agi, int, sen, vit

    var id: String { rawValue }

    var label: String {
        switch self {
        case .str: "STR"
        case .agi: "AGI"
        case .int: "INT"
        case .sen: "SEN"
        case .vit: "VIT"
        }
    }

    var fullName: String {
        switch self {
        case .str: "Strength"
        case .agi: "Agility"
        case .int: "Intellect"
        case .sen: "Sense"
        case .vit: "Vitality"
        }
    }
}

enum QuestStatus: String, Codable {
    case assigned
    case completed
    case missed
}

enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case easy, normal, hard, extreme

    var id: String { rawValue }

    var label: String {
        switch self {
        case .easy: "E"
        case .normal: "N"
        case .hard: "H"
        case .extreme: "EX"
        }
    }

    var xpMultiplier: Double {
        switch self {
        case .easy: 0.6
        case .normal: 1.0
        case .hard: 1.6
        case .extreme: 2.5
        }
    }
}

enum Rank: String, Codable, CaseIterable, Identifiable, Comparable {
    case E, D, C, B, A, S, SS, NATIONAL

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .NATIONAL: "NATIONAL"
        default: rawValue
        }
    }

    static let order: [Rank] = [.E, .D, .C, .B, .A, .S, .SS, .NATIONAL]

    static func < (lhs: Rank, rhs: Rank) -> Bool {
        guard let l = order.firstIndex(of: lhs), let r = order.firstIndex(of: rhs) else { return false }
        return l < r
    }

    /// Level threshold at which this rank begins.
    var threshold: Int {
        switch self {
        case .E: 1
        case .D: 10
        case .C: 25
        case .B: 45
        case .A: 70
        case .S: 100
        case .SS: 140
        case .NATIONAL: 200
        }
    }

    static func forLevel(_ level: Int) -> Rank {
        order.reversed().first { level >= $0.threshold } ?? .E
    }
}
