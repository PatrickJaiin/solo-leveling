import SwiftUI
import SwiftData

struct AppAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let isError: Bool
}

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(QuestEngine.self) private var engine
    @Environment(\.modelContext) private var context
    let hunter: Hunter
    let healthKit: HealthKitService
    let eventKit: EventKitService
    let notifications: NotificationService

    @State private var apiKeyInput: String = ""
    @State private var apiKeySaved: Bool = false
    @State private var apiKeyError: String?
    @State private var testing: Bool = false
    @State private var alertItem: AppAlert?

    // Baseline form scratch state (Bindable directly on optionals is awkward for TextField).
    @State private var hunterAge: String = ""
    @State private var hunterHeight: String = ""
    @State private var hunterWeight: String = ""
    @State private var hunterGender: String = ""
    @State private var hunterCity: String = ""
    @State private var hunterOccupation: String = ""
    @State private var hunterSalary: String = ""
    @State private var hunterEducation: String = ""
    @State private var hunterYearsExp: String = ""
    @State private var hunterFitness: String = ""
    @State private var hunterNotes: String = ""

    var body: some View {
        @Bindable var settings = settings
        ScrollView {
            VStack(spacing: 16) {
                SystemPanel("Hunter", tint: Theme.systemBlue) {
                    VStack(alignment: .leading, spacing: 10) {
                        labeled("Name") {
                            TextField("Hunter", text: Bindable(hunter).name)
                                .textFieldStyle(.plain)
                                .font(Typography.body).foregroundStyle(.white)
                                .padding(8)
                                .background(NotchedRectangle(notch: 4).stroke(Theme.systemBlue.opacity(0.4), lineWidth: 1))
                        }
                    }
                }

                SystemPanel("Personal Baseline", tint: Theme.systemCyan) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("The AI uses these to weight XP fairly. Harder-for-you tasks pay more.")
                            .font(Typography.systemTag).foregroundStyle(Theme.dim)

                        HStack(spacing: 10) {
                            numberField("Age", $hunterAge, placeholder: "27")
                            numberField("Height (cm)", $hunterHeight, placeholder: "180")
                            numberField("Weight (kg)", $hunterWeight, placeholder: "75")
                        }
                        HStack(spacing: 10) {
                            stringField("Gender", $hunterGender, placeholder: "—")
                            stringField("City", $hunterCity, placeholder: "Bengaluru")
                        }
                        stringField("Occupation", $hunterOccupation, placeholder: "e.g. software engineer at a startup")
                        HStack(spacing: 10) {
                            stringField("Salary band", $hunterSalary, placeholder: "student / junior / mid / senior / staff / exec")
                            stringField("Education", $hunterEducation, placeholder: "Bachelors / Masters / etc.")
                            numberField("Years exp", $hunterYearsExp, placeholder: "3")
                        }
                        stringField("Fitness baseline", $hunterFitness, placeholder: "sedentary / light / moderate / athletic")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ANYTHING ELSE THE SYSTEM SHOULD KNOW")
                                .font(Typography.systemTag).foregroundStyle(Theme.dim)
                            TextEditor(text: $hunterNotes)
                                .font(Typography.body)
                                .foregroundStyle(.white)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 60)
                                .padding(6)
                                .background(NotchedRectangle(notch: 4).stroke(Theme.systemCyan.opacity(0.4), lineWidth: 1))
                        }

                        HStack {
                            Button {
                                applyBaselineToHunter()
                                let ok = ProfileStore.write(hunter.baselineMarkdown)
                                alertItem = AppAlert(title: ok ? "Profile saved" : "Saved (markdown write failed)",
                                                     message: ok
                                                       ? "Baseline saved to the Hunter record and mirrored to profile.md."
                                                       : "Baseline saved but couldn't write the markdown file.",
                                                     isError: !ok)
                            } label: {
                                Text("Save Baseline")
                            }
                            .buttonStyle(.borderedProminent).tint(Theme.systemCyan)

                            Button("Open profile.md") { ProfileStore.revealInFinder() }
                                .buttonStyle(.bordered)
                        }
                    }
                }

                SystemPanel("AI Quest Generation", tint: Theme.systemCyan) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $settings.useAI) {
                            Text("Let the AI generate today's quests")
                                .font(Typography.body).foregroundStyle(.white)
                        }
                        .toggleStyle(.switch).tint(Theme.systemCyan)

                        Text("PROVIDER").font(Typography.systemTag).foregroundStyle(Theme.dim)
                        Picker("", selection: $settings.aiProviderRaw) {
                            ForEach(AIProvider.allCases) { p in
                                Text(p.label).tag(p.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        Text("\(settings.aiProvider == .claude ? "ANTHROPIC" : "GEMINI")_API_KEY")
                            .font(Typography.systemTag).foregroundStyle(Theme.dim)
                        SecureField(apiKeySaved ? "•••••••• (saved to Keychain)" : settings.aiProvider.keyHint,
                                    text: $apiKeyInput)
                            .textFieldStyle(.plain)
                            .font(Typography.body).foregroundStyle(.white)
                            .padding(8)
                            .background(NotchedRectangle(notch: 4).stroke(Theme.systemCyan.opacity(0.4), lineWidth: 1))

                        HStack {
                            Button {
                                saveKey()
                            } label: {
                                Text("Save Key")
                            }
                            .buttonStyle(.borderedProminent).tint(Theme.systemCyan)
                            .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            Button {
                                Task { await testKey() }
                            } label: {
                                HStack(spacing: 6) {
                                    if testing { ProgressView().controlSize(.mini) }
                                    Text(testing ? "Testing…" : "Test Key")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(testing || !apiKeySaved)

                            Button("Clear Key") {
                                Keychain.deleteAPIKey(for: settings.aiProvider.keychainAccount)
                                apiKeySaved = false
                                apiKeyError = nil
                                alertItem = AppAlert(title: "Key removed",
                                                     message: "Cleared the \(settings.aiProvider.label) key from Keychain.",
                                                     isError: false)
                            }
                            .buttonStyle(.bordered)

                            Link(destination: URL(string: settings.aiProvider.consoleURL)!) {
                                Text("Get a \(settings.aiProvider.label) key ↗")
                                    .font(Typography.systemTag).foregroundStyle(Theme.systemCyan)
                            }
                        }
                        if let apiKeyError {
                            Text(apiKeyError).font(Typography.systemTag).foregroundStyle(Theme.danger)
                        }
                        Text(currentProviderHelp)
                            .font(Typography.systemTag).foregroundStyle(Theme.dim)
                    }
                }

                SystemPanel("Integrations", tint: Theme.systemGold) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $settings.useHealthKit) {
                            Text("Auto-complete fitness quests from HealthKit")
                                .font(Typography.body).foregroundStyle(.white)
                        }
                        .toggleStyle(.switch).tint(Theme.systemGold)

                        Toggle(isOn: $settings.useCalendar) {
                            Text("Show today's Calendar events as Scheduled Encounters")
                                .font(Typography.body).foregroundStyle(.white)
                        }
                        .toggleStyle(.switch).tint(Theme.systemGold)

                        HStack {
                            Button("Request HealthKit access") { Task { await healthKit.requestAuthorization() } }
                            Button("Request Calendar access") { Task { await eventKit.requestAuthorization() } }
                            Button("Request Notifications") { Task { await notifications.requestAuthorization() } }
                        }
                    }
                }

                SystemPanel("HUD", tint: Theme.systemBlue) {
                    Toggle(isOn: $settings.hudEnabled) {
                        Text("Show floating quest HUD (always on top)")
                            .font(Typography.body).foregroundStyle(.white)
                    }
                    .toggleStyle(.switch).tint(Theme.systemBlue)
                }

                SystemPanel("Daily Reminder", tint: Theme.systemBlue) {
                    HStack(spacing: 12) {
                        Stepper(value: $settings.morningHour, in: 4...12) {
                            Text("Morning quest issued at \(settings.morningHour):00")
                                .font(Typography.body).foregroundStyle(.white)
                        }
                        Button("Schedule") {
                            notifications.scheduleDailyMorning(hour: settings.morningHour)
                            alertItem = AppAlert(title: "Reminder scheduled",
                                                 message: "Daily morning notification set for \(settings.morningHour):00.",
                                                 isError: false)
                        }
                    }
                }

                SystemPanel("Sanctioned Rest", tint: Theme.systemGold) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Invoke once per ~14 days. Today's misses do not levy debt; the streak survives.")
                            .font(Typography.systemTag).foregroundStyle(Theme.dim)
                        HStack(spacing: 12) {
                            Button {
                                engine.invokeRestDay(hunter: hunter, context: context)
                                alertItem = AppAlert(
                                    title: "[ REST DECREED ]",
                                    message: "Today is now a Sanctioned Rest Day. No debt will be levied. Misses do not break your streak.",
                                    isError: false)
                            } label: {
                                Text(engine.canInvokeRest(hunter: hunter) ? "[ INVOKE REST DAY ]" : "[ ON COOLDOWN ]")
                                    .font(Typography.systemTag)
                                    .foregroundStyle(engine.canInvokeRest(hunter: hunter) ? Theme.systemGold : Theme.dim)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(NotchedRectangle(notch: 4).fill(Theme.systemGold.opacity(engine.canInvokeRest(hunter: hunter) ? 0.12 : 0.04)))
                                    .overlay(NotchedRectangle(notch: 4).stroke(engine.canInvokeRest(hunter: hunter) ? Theme.systemGold : Theme.dim, lineWidth: 1))
                                    .contentShape(NotchedRectangle(notch: 4))
                            }
                            .buttonStyle(.plain)
                            .disabled(!engine.canInvokeRest(hunter: hunter))

                            if let next = engine.nextRestEligibleDayKey(hunter: hunter),
                               !engine.canInvokeRest(hunter: hunter) {
                                Text("Next eligible: \(next)")
                                    .font(Typography.systemTag).foregroundStyle(Theme.dim)
                            }
                            if hunter.activeRestDayKey == DayKey.key() {
                                SystemTag(text: "RESTING TODAY", tint: Theme.systemGold)
                            }
                        }
                    }
                }

                SystemPanel("Danger Zone", tint: Theme.danger) {
                    Button("Reset Hunter (delete all data)") {
                        resetEverything()
                        alertItem = AppAlert(title: "Hunter reset",
                                             message: "Profile wiped. The System has reissued an E-Rank.",
                                             isError: false)
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.danger)
                }
            }
            .padding(20)
        }
        .onAppear { refreshKeyState(); loadBaselineFields() }
        .onChange(of: settings.aiProviderRaw) { _, _ in refreshKeyState() }
        .alert(item: $alertItem) { item in
            Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("OK")))
        }
    }

    private func saveKey() {
        let key = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let ok = Keychain.saveAPIKey(key, for: settings.aiProvider.keychainAccount)
        if ok {
            apiKeyInput = ""
            apiKeySaved = true
            apiKeyError = nil
            alertItem = AppAlert(
                title: "Key saved",
                message: "\(settings.aiProvider.label) key stored in Keychain. Tap Test Key to verify it works.",
                isError: false)
        } else {
            apiKeyError = "Keychain refused to save. Make sure the app is code-signed (Xcode handles this when you Run)."
            alertItem = AppAlert(title: "Save failed",
                                 message: apiKeyError ?? "",
                                 isError: true)
        }
    }

    private func testKey() async {
        testing = true
        defer { testing = false }
        do {
            try await engine.ping(provider: settings.aiProvider)
            alertItem = AppAlert(
                title: "Key works",
                message: "\(settings.aiProvider.label) responded. You're good to issue quests.",
                isError: false)
        } catch {
            alertItem = AppAlert(
                title: "Key rejected",
                message: error.localizedDescription,
                isError: true)
        }
    }

    private func refreshKeyState() {
        apiKeySaved = Keychain.loadAPIKey(for: settings.aiProvider.keychainAccount) != nil
        apiKeyInput = ""
        apiKeyError = nil
    }

    private var currentProviderHelp: String {
        switch settings.aiProvider {
        case .claude: "Claude Sonnet 4.6 — paid, ~¢1 per daily generation. Best prose quality."
        case .gemini: "Gemini 2.5 Flash — has a generous free tier on AI Studio. Fast."
        }
    }

    private func labeled<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(Typography.systemTag).foregroundStyle(Theme.dim)
            content()
        }
    }

    private func loadBaselineFields() {
        hunterAge = hunter.age.map(String.init) ?? ""
        hunterHeight = hunter.heightCm.map(String.init) ?? ""
        hunterWeight = hunter.weightKg.map(String.init) ?? ""
        hunterGender = hunter.gender ?? ""
        hunterCity = hunter.city ?? ""
        hunterOccupation = hunter.occupation ?? ""
        hunterSalary = hunter.salaryBand ?? ""
        hunterEducation = hunter.educationLevel ?? ""
        hunterYearsExp = hunter.yearsExperience.map(String.init) ?? ""
        hunterFitness = hunter.fitnessBaseline ?? ""
        hunterNotes = hunter.personalNotes ?? ""
    }

    private func applyBaselineToHunter() {
        hunter.age = Int(hunterAge)
        hunter.heightCm = Int(hunterHeight)
        hunter.weightKg = Int(hunterWeight)
        hunter.gender = blankToNil(hunterGender)
        hunter.city = blankToNil(hunterCity)
        hunter.occupation = blankToNil(hunterOccupation)
        hunter.salaryBand = blankToNil(hunterSalary)
        hunter.educationLevel = blankToNil(hunterEducation)
        hunter.yearsExperience = Int(hunterYearsExp)
        hunter.fitnessBaseline = blankToNil(hunterFitness)
        hunter.personalNotes = blankToNil(hunterNotes)
    }

    private func blankToNil(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private func stringField(_ label: String, _ binding: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(Typography.systemTag).foregroundStyle(Theme.dim)
            TextField(placeholder, text: binding)
                .textFieldStyle(.plain)
                .font(Typography.body).foregroundStyle(.white)
                .padding(8)
                .background(NotchedRectangle(notch: 4).stroke(Theme.systemCyan.opacity(0.4), lineWidth: 1))
        }
    }

    private func numberField(_ label: String, _ binding: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased()).font(Typography.systemTag).foregroundStyle(Theme.dim)
            TextField(placeholder, text: binding)
                .textFieldStyle(.plain)
                .font(Typography.body).foregroundStyle(.white)
                .padding(8)
                .frame(maxWidth: 120)
                .background(NotchedRectangle(notch: 4).stroke(Theme.systemCyan.opacity(0.4), lineWidth: 1))
        }
    }

    private func resetEverything() {
        try? context.delete(model: Quest.self)
        try? context.delete(model: Shadow.self)
        try? context.delete(model: DailyLog.self)
        hunter.name = "Hunter"
        hunter.title = "The Weakest E-Rank"
        hunter.level = 1
        hunter.xp = 0
        hunter.str = 5; hunter.agi = 5; hunter.intStat = 5; hunter.sen = 5; hunter.vit = 5
        hunter.unspentPoints = 0
        hunter.lifetimeQuestsCompleted = 0
        hunter.lastQuestDayKey = ""
        hunter.lastActiveDayKey = ""
        hunter.dayStreak = 0
        hunter.inPenaltyZone = false
    }
}
