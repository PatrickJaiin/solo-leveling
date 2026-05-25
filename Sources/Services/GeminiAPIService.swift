import Foundation

enum GeminiAPIError: LocalizedError {
    case missingAPIKey
    case http(Int, String)
    case decode(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: "No Gemini API key set. Add one in Settings."
        case .http(let code, let body): "HTTP \(code): \(body.prefix(200))"
        case .decode(let s): "Decode error: \(s)"
        case .empty: "Gemini returned no quests."
        }
    }
}

/// Google Gemini quest generator. Uses Gemini 2.5 Flash with native structured-JSON output
/// (`responseSchema`) — no fence-stripping needed.
@MainActor
final class GeminiAPIService: QuestGenerator {
    static let model = "gemini-2.5-flash"
    static var endpoint: URL {
        URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
    }
    static let timeoutSeconds: TimeInterval = 30

    func generateDailyQuests(hunter: Hunter,
                              isPenalty: Bool,
                              isSunday: Bool,
                              count: Int) async throws -> [QuestTemplate] {
        guard let key = Keychain.loadAPIKey(for: .gemini), !key.isEmpty else {
            throw GeminiAPIError.missingAPIKey
        }

        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = Self.timeoutSeconds
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(key, forHTTPHeaderField: "x-goog-api-key")

        let user = Self.userPrompt(hunter: hunter, isPenalty: isPenalty, isSunday: isSunday, count: count)

        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [["text": Self.systemPrompt]]
            ],
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": user]]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": Self.responseSchema,
                "temperature": 0.8,
                "maxOutputTokens": 2048
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw GeminiAPIError.http(-1, "no response")
        }
        if http.statusCode >= 300 {
            let bodyText = String(data: data, encoding: .utf8) ?? "<no body>"
            throw GeminiAPIError.http(http.statusCode, bodyText)
        }

        return try Self.parse(data)
    }

    // MARK: - Schema

    /// `responseSchema` is Gemini's subset of OpenAPI 3.0 schema. `enum` is a top-level
    /// field on string types; `type` is UPPERCASE.
    private static let responseSchema: [String: Any] = [
        "type": "OBJECT",
        "properties": [
            "quests": [
                "type": "ARRAY",
                "items": [
                    "type": "OBJECT",
                    "properties": [
                        "title": ["type": "STRING"],
                        "detail": ["type": "STRING"],
                        "pillar": ["type": "STRING", "enum": ["work", "fitness", "mental", "vitality"]],
                        "difficulty": ["type": "STRING", "enum": ["easy", "normal", "hard", "extreme"]],
                        "baseXP": ["type": "INTEGER"],
                        "statReward": ["type": "STRING", "enum": ["str", "agi", "int", "sen", "vit"]],
                        "autoCompletable": ["type": "BOOLEAN"]
                    ],
                    "required": ["title", "pillar", "difficulty", "baseXP", "statReward"]
                ]
            ]
        ],
        "required": ["quests"]
    ]

    // MARK: - Prompts (mirrors ClaudeAPIService for parity)

    private static let systemPrompt = """
    You are the System from the manhwa "Solo Leveling" — a curt, mysterious entity that issues
    daily quests to a Hunter to make them stronger across four pillars:
      - Work (INT)
      - Fitness (STR / AGI)
      - Mental (SEN)
      - Vitality (VIT)

    Quests must be:
      - Specific, timeboxed, completable today.
      - In the System's voice: imperative, terse, slightly ominous, no fluff.
      - Spread across all four pillars unless told otherwise.

    Lower-stat pillars get slightly harder quests — the System forces growth where the Hunter
    is weakest. Set autoCompletable=true ONLY for quests HealthKit can verify (steps, workout
    minutes, sleep hours).

    Respond with a JSON object matching the schema. No prose, no preamble.
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

        Issue exactly \(count) quests now.
        """
    }

    // MARK: - Response parsing

    private static func parse(_ data: Data) throws -> [QuestTemplate] {
        struct Part: Decodable { let text: String? }
        struct Content: Decodable { let parts: [Part]? }
        struct Candidate: Decodable {
            let content: Content?
            let finishReason: String?
        }
        struct Resp: Decodable { let candidates: [Candidate]? }

        let resp: Resp
        do { resp = try JSONDecoder().decode(Resp.self, from: data) }
        catch { throw GeminiAPIError.decode(String(describing: error)) }

        let text = resp.candidates?
            .first?.content?.parts?
            .compactMap { $0.text }.joined() ?? ""
        guard !text.isEmpty else { throw GeminiAPIError.empty }

        struct Wrapper: Decodable { let quests: [DTO] }
        struct DTO: Decodable {
            let title: String
            let detail: String?
            let pillar: String
            let difficulty: String?
            let baseXP: Int?
            let statReward: String?
            let autoCompletable: Bool?
        }
        guard let inner = text.data(using: .utf8) else { throw GeminiAPIError.decode("not utf8") }
        let wrapper: Wrapper
        do { wrapper = try JSONDecoder().decode(Wrapper.self, from: inner) }
        catch { throw GeminiAPIError.decode("schema mismatch: \(error)") }

        return wrapper.quests.map { dto in
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
