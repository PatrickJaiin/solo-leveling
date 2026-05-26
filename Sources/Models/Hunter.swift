import Foundation
import SwiftData

@Model
final class Hunter {
    var name: String
    var title: String
    var level: Int
    var xp: Int

    var str: Int
    var agi: Int
    var intStat: Int
    var sen: Int
    var vit: Int

    /// Unallocated stat points the user can spend on level-up.
    var unspentPoints: Int

    /// Total quests completed across all time (drives some title/rank unlocks).
    var lifetimeQuestsCompleted: Int

    /// YYYY-MM-DD of the last day for which quests were generated.
    var lastQuestDayKey: String

    /// YYYY-MM-DD of the last completed daily reset (drives the streak meter).
    var lastActiveDayKey: String

    /// Consecutive days with >=1 completed non-penalty quest.
    var dayStreak: Int

    /// If true, today started in the Penalty Zone (more than half of yesterday's quests were missed).
    var inPenaltyZone: Bool

    /// Accumulated XP that must be paid down before new XP banks. Missed quests stamp the ledger.
    /// Replaces the old "bonus multiplier for penalty days" (which rewarded failure — exploitable).
    /// Default literal is important — SwiftData lightweight migration needs it for old records.
    var xpDebt: Int = 0

    /// YYYY-MM-DD of the last Sanctioned Rest Day. Used to enforce the 14-day cooldown.
    var lastRestDayKey: String?

    /// YYYY-MM-DD of the rest day currently being honored (set when the user invokes Rest for today).
    var activeRestDayKey: String?

    // MARK: - Personal baseline (optional — drives XP weighting in the AI prompt)

    var age: Int?
    var heightCm: Int?
    var weightKg: Int?
    var gender: String?
    var occupation: String?
    var salaryBand: String?         // free text: "student", "junior IC", "mid", "senior", "staff", "exec"
    var educationLevel: String?     // free text: "HS", "Bachelors", "Masters", "PhD", etc.
    var yearsExperience: Int?
    var city: String?
    var fitnessBaseline: String?    // "sedentary" | "light" | "moderate" | "athletic"
    var personalNotes: String?      // free-text "anything else the System should know"

    init(name: String = "Hunter",
         title: String = "The Weakest E-Rank",
         level: Int = 1,
         xp: Int = 0,
         str: Int = 5,
         agi: Int = 5,
         intStat: Int = 5,
         sen: Int = 5,
         vit: Int = 5,
         unspentPoints: Int = 0,
         lifetimeQuestsCompleted: Int = 0,
         lastQuestDayKey: String = "",
         lastActiveDayKey: String = "",
         dayStreak: Int = 0,
         inPenaltyZone: Bool = false,
         xpDebt: Int = 0,
         lastRestDayKey: String? = nil,
         activeRestDayKey: String? = nil,
         age: Int? = nil,
         heightCm: Int? = nil,
         weightKg: Int? = nil,
         gender: String? = nil,
         occupation: String? = nil,
         salaryBand: String? = nil,
         educationLevel: String? = nil,
         yearsExperience: Int? = nil,
         city: String? = nil,
         fitnessBaseline: String? = nil,
         personalNotes: String? = nil) {
        self.name = name
        self.title = title
        self.level = level
        self.xp = xp
        self.str = str
        self.agi = agi
        self.intStat = intStat
        self.sen = sen
        self.vit = vit
        self.unspentPoints = unspentPoints
        self.lifetimeQuestsCompleted = lifetimeQuestsCompleted
        self.lastQuestDayKey = lastQuestDayKey
        self.lastActiveDayKey = lastActiveDayKey
        self.dayStreak = dayStreak
        self.inPenaltyZone = inPenaltyZone
        self.xpDebt = xpDebt
        self.lastRestDayKey = lastRestDayKey
        self.activeRestDayKey = activeRestDayKey
        self.age = age
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.gender = gender
        self.occupation = occupation
        self.salaryBand = salaryBand
        self.educationLevel = educationLevel
        self.yearsExperience = yearsExperience
        self.city = city
        self.fitnessBaseline = fitnessBaseline
        self.personalNotes = personalNotes
    }

    /// Markdown-shaped profile passed to the AI as context. Compact, omits empty fields.
    var baselineMarkdown: String {
        var parts: [String] = []
        parts.append("# Hunter Profile — \(name)")
        parts.append("")
        parts.append("Level \(level) · Rank \(rank.displayName) · Streak \(dayStreak)d · Lifetime quests: \(lifetimeQuestsCompleted)")
        parts.append("Current stats — STR \(str) / AGI \(agi) / INT \(intStat) / SEN \(sen) / VIT \(vit)")

        var personal: [String] = []
        if let age { personal.append("age: \(age)") }
        if let gender, !gender.isEmpty { personal.append("gender: \(gender)") }
        if let heightCm { personal.append("height: \(heightCm) cm") }
        if let weightKg { personal.append("weight: \(weightKg) kg") }
        if let city, !city.isEmpty { personal.append("city: \(city)") }
        if let fitnessBaseline, !fitnessBaseline.isEmpty { personal.append("fitness baseline: \(fitnessBaseline)") }
        if !personal.isEmpty {
            parts.append("")
            parts.append("## Personal")
            parts.append(personal.joined(separator: " · "))
        }

        var career: [String] = []
        if let occupation, !occupation.isEmpty { career.append("occupation: \(occupation)") }
        if let salaryBand, !salaryBand.isEmpty { career.append("salary band: \(salaryBand)") }
        if let educationLevel, !educationLevel.isEmpty { career.append("education: \(educationLevel)") }
        if let yearsExperience { career.append("years of experience: \(yearsExperience)") }
        if !career.isEmpty {
            parts.append("")
            parts.append("## Career")
            parts.append(career.joined(separator: " · "))
        }

        if let personalNotes, !personalNotes.isEmpty {
            parts.append("")
            parts.append("## Notes")
            parts.append(personalNotes)
        }

        return parts.joined(separator: "\n")
    }

    var rank: Rank { Rank.forLevel(level) }

    func stat(_ key: StatKey) -> Int {
        switch key {
        case .str: str
        case .agi: agi
        case .int: intStat
        case .sen: sen
        case .vit: vit
        }
    }

    func addStat(_ key: StatKey, _ amount: Int) {
        switch key {
        case .str: str += amount
        case .agi: agi += amount
        case .int: intStat += amount
        case .sen: sen += amount
        case .vit: vit += amount
        }
    }
}
