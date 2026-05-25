import Foundation

enum ClaudeAPIError: LocalizedError {
    case missingAPIKey
    case http(Int, String)
    case decode(String)
    case truncated
    case noToolUse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "No Anthropic API key set. Add one in Settings."
        case .http(let code, let body): "HTTP \(code): \(body.prefix(200))"
        case .decode(let s): "Decode error: \(s)"
        case .truncated: "Response was truncated (max_tokens). Try fewer quests."
        case .noToolUse: "Model did not call the issue_quests tool."
        }
    }
}

@MainActor
final class ClaudeAPIService: QuestGenerator {
    /// Sonnet 4.6 — appropriate for creative quest generation; fast, cheap, capable.
    static let model = "claude-sonnet-4-6"
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let anthropicVersion = "2023-06-01"
    static let timeoutSeconds: TimeInterval = 30

    func generateDailyQuests(hunter: Hunter,
                              isPenalty: Bool,
                              isSunday: Bool,
                              count: Int) async throws -> [QuestTemplate] {
        guard let key = Keychain.loadAPIKey(for: .anthropic), !key.isEmpty else {
            throw ClaudeAPIError.missingAPIKey
        }

        let user = Self.userPrompt(hunter: hunter, isPenalty: isPenalty, isSunday: isSunday, count: count)

        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = Self.timeoutSeconds
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue(Self.anthropicVersion, forHTTPHeaderField: "anthropic-version")

        // Tool-use schema forces structured JSON output — no fence-stripping, no prose leak.
        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 2000,
            "system": Self.systemPrompt,
            "tools": [Self.questTool],
            "tool_choice": ["type": "tool", "name": "issue_quests"],
            "messages": [
                ["role": "user", "content": user]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw ClaudeAPIError.http(-1, "no response")
        }
        if http.statusCode >= 300 {
            let bodyText = String(data: data, encoding: .utf8) ?? "<no body>"
            throw ClaudeAPIError.http(http.statusCode, bodyText)
        }

        return try Self.parseToolUse(from: data)
    }

    // MARK: - Tool schema

    private static let questTool: [String: Any] = [
        "name": "issue_quests",
        "description": "Issue today's quest set to the Hunter. Call this exactly once with all quests.",
        "input_schema": [
            "type": "object",
            "properties": [
                "quests": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "title": ["type": "string", "description": "Imperative, <60 chars."],
                            "detail": ["type": "string", "description": "One sentence, <120 chars."],
                            "pillar": ["type": "string", "enum": ["work", "fitness", "mental", "vitality"]],
                            "difficulty": ["type": "string", "enum": ["easy", "normal", "hard", "extreme"]],
                            "baseXP": ["type": "integer", "minimum": 30, "maximum": 200],
                            "statReward": ["type": "string", "enum": ["str", "agi", "int", "sen", "vit"]],
                            "autoCompletable": ["type": "boolean", "description": "True only if HealthKit can confirm (steps/workout/sleep)."]
                        ],
                        "required": ["title", "pillar", "difficulty", "baseXP", "statReward"]
                    ]
                ]
            ],
            "required": ["quests"]
        ]
    ]

    // MARK: - Prompts

    private static let systemPrompt = """
    You are the System from the manhwa "Solo Leveling" — a curt, mysterious entity that issues
    daily quests to a Hunter to make them stronger across four pillars:
      - Work (INT)
      - Fitness (STR / AGI)
      - Mental (SEN)
      - Vitality (VIT)

    Quests you generate must be:
      - Specific, timeboxed, and completable today.
      - Phrased in the System's voice — imperative, terse, slightly ominous, no fluff.
      - Spread across all four pillars unless instructed otherwise.

    Lower-stat pillars deserve slightly harder quests — the System forces growth where the Hunter
    is weakest. Set autoCompletable=true ONLY for quests HealthKit can verify (step count,
    workout minutes, sleep hours).

    Call the `issue_quests` tool exactly once with the full set.
    """

    private static func userPrompt(hunter: Hunter, isPenalty: Bool, isSunday: Bool, count: Int) -> String {
        """
        Hunter profile:
          name: \(hunter.name)
          level: \(hunter.level)
          rank: \(hunter.rank.displayName)
          stats: STR \(hunter.str) / AGI \(hunter.agi) / INT \(hunter.intStat) / SEN \(hunter.sen) / VIT \(hunter.vit)
          streak: \(hunter.dayStreak) days
          lifetime quests completed: \(hunter.lifetimeQuestsCompleted)

        Constraints for today's quest set:
          - Total quests: \(count)
          - Penalty Zone: \(isPenalty ? "YES — quests harder than usual, sterner tone." : "no")
          - Sunday review day: \(isSunday ? "yes — include at least one reflective/planning quest" : "no")

        Issue exactly \(count) quests via the issue_quests tool now.
        """
    }

    // MARK: - Tool-use response parsing

    private static func parseToolUse(from data: Data) throws -> [QuestTemplate] {
        struct Block: Decodable {
            let type: String
            let name: String?
            let input: ToolInput?
        }
        struct ToolInput: Decodable {
            let quests: [DTO]
        }
        struct DTO: Decodable {
            let title: String
            let detail: String?
            let pillar: String
            let difficulty: String?
            let baseXP: Int?
            let statReward: String?
            let autoCompletable: Bool?
        }
        struct Resp: Decodable {
            let stop_reason: String?
            let content: [Block]
        }

        let resp: Resp
        do { resp = try JSONDecoder().decode(Resp.self, from: data) }
        catch { throw ClaudeAPIError.decode(String(describing: error)) }

        if resp.stop_reason == "max_tokens" { throw ClaudeAPIError.truncated }

        guard let toolBlock = resp.content.first(where: { $0.type == "tool_use" && $0.name == "issue_quests" }),
              let input = toolBlock.input else {
            throw ClaudeAPIError.noToolUse
        }

        return input.quests.map { dto in
            let pillar = Pillar(rawValue: dto.pillar.lowercased()) ?? .work
            let diff = Difficulty(rawValue: dto.difficulty?.lowercased() ?? "normal") ?? .normal
            let stat = StatKey(rawValue: dto.statReward?.lowercased() ?? "") ?? pillar.primaryStat
            return QuestTemplate(
                title: dto.title,
                detail: dto.detail ?? "",
                pillar: pillar,
                difficulty: diff,
                baseXP: dto.baseXP ?? 50,
                statReward: stat,
                autoCompletable: dto.autoCompletable ?? false
            )
        }
    }
}
