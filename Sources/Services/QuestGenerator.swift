import Foundation

enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case claude
    case gemini

    var id: String { rawValue }
    var label: String {
        switch self {
        case .claude: "Claude"
        case .gemini: "Gemini"
        }
    }
    var keychainAccount: Keychain.Account {
        switch self {
        case .claude: .anthropic
        case .gemini: .gemini
        }
    }
    var keyHint: String {
        switch self {
        case .claude: "sk-ant-..."
        case .gemini: "AIzaSy..."
        }
    }
    var consoleURL: String {
        switch self {
        case .claude: "https://console.anthropic.com/settings/keys"
        case .gemini: "https://aistudio.google.com/app/apikey"
        }
    }
}

/// Common protocol implemented by ClaudeAPIService and GeminiAPIService.
@MainActor
protocol QuestGenerator {
    func generateDailyQuests(hunter: Hunter,
                              isPenalty: Bool,
                              isSunday: Bool,
                              count: Int) async throws -> [QuestTemplate]
}
