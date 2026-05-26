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

    func scoreQuest(title: String, detail: String, hunter: Hunter) async throws -> QuestTemplate {
        guard let key = Keychain.loadAPIKey(for: .anthropic), !key.isEmpty else {
            throw ClaudeAPIError.missingAPIKey
        }
        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = Self.timeoutSeconds
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue(Self.anthropicVersion, forHTTPHeaderField: "anthropic-version")

        let user = """
        \(hunter.baselineMarkdown)

        The Hunter has manually proposed this quest:
          title: \(title)
          detail: \(detail.isEmpty ? "(none provided)" : detail)

        Score this single quest for them, using their baseline to weight baseXP fairly.
        Call the `score_quest` tool once.
        """

        let scoreTool: [String: Any] = [
            "name": "score_quest",
            "description": "Score a single user-proposed quest with pillar/difficulty/baseXP/statReward.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "title": ["type": "string"],
                    "detail": ["type": "string"],
                    "pillar": ["type": "string", "enum": ["work", "fitness", "mental", "vitality"]],
                    "difficulty": ["type": "string", "enum": ["easy", "normal", "hard", "extreme"]],
                    "baseXP": ["type": "integer", "minimum": 20, "maximum": 200],
                    "statReward": ["type": "string", "enum": ["str", "agi", "int", "sen", "vit"]],
                    "autoCompletable": ["type": "boolean"]
                ],
                "required": ["title", "pillar", "difficulty", "baseXP", "statReward"]
            ]
        ]

        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 600,
            "system": Self.systemPrompt,
            "tools": [scoreTool],
            "tool_choice": ["type": "tool", "name": "score_quest"],
            "messages": [["role": "user", "content": user]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw ClaudeAPIError.http(-1, "no response") }
        if http.statusCode >= 300 {
            throw ClaudeAPIError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return try Self.parseSingleScore(from: data)
    }

    private static func parseSingleScore(from data: Data) throws -> QuestTemplate {
        struct Block: Decodable {
            let type: String
            let name: String?
            let input: DTO?
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

        let resp = try JSONDecoder().decode(Resp.self, from: data)
        guard let dto = resp.content.first(where: { $0.type == "tool_use" && $0.name == "score_quest" })?.input else {
            throw ClaudeAPIError.noToolUse
        }
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

    func ping() async throws -> String {
        guard let key = Keychain.loadAPIKey(for: .anthropic), !key.isEmpty else {
            throw ClaudeAPIError.missingAPIKey
        }
        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue(Self.anthropicVersion, forHTTPHeaderField: "anthropic-version")
        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 10,
            "messages": [["role": "user", "content": "Reply with the single word: OK"]]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw ClaudeAPIError.http(-1, "no response") }
        if http.statusCode >= 300 {
            throw ClaudeAPIError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return "ok"
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

    ## XP weighting — the balanced playing field

    Set `baseXP` based on TWO factors:
      1. Objective task difficulty (small / medium / large / heroic effort).
      2. PERSONAL difficulty for THIS Hunter, derived from their profile.

    Examples of personal weighting:
      - "Run 5km" is ~30 XP for an athletic 25-year-old, ~90 XP for a sedentary 50-year-old.
      - "Send 5 cold outreach emails" is ~30 XP for a senior staff engineer with strong network,
        ~80 XP for a fresh grad with no network — same task, very different friction.
      - "Read a research paper" is ~40 XP for a PhD, ~80 XP for someone without a college degree.

    The point is fairness across baselines — a Hunter with privilege gets less XP for tasks
    that come easy; a Hunter starting further back gets more XP for the same nominal task.
    Use the Hunter's demographics, salary band, education, network/occupation, and fitness
    baseline to scale appropriately. baseXP range: 20..200.

    Lower-stat pillars deserve slightly harder quests — the System forces growth where the
    Hunter is weakest. Set autoCompletable=true ONLY for quests HealthKit can verify (step
    count, workout minutes, sleep hours).

    Call the `issue_quests` tool exactly once with the full set.
    """

    private static func userPrompt(hunter: Hunter, isPenalty: Bool, isSunday: Bool, count: Int) -> String {
        """
        \(hunter.baselineMarkdown)

        Constraints for today's quest set:
          - Total quests: \(count)
          - Penalty Zone: \(isPenalty ? "YES — quests harder than usual, sterner tone." : "no")
          - Sunday review day: \(isSunday ? "yes — include at least one reflective/planning quest" : "no")

        Issue exactly \(count) quests via the issue_quests tool now.
        Remember to weight baseXP using the Hunter's profile (age, fitness, salary band,
        education, occupation) so harder-for-them tasks pay more.
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
