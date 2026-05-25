import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    let hunter: Hunter
    let healthKit: HealthKitService
    let eventKit: EventKitService
    let notifications: NotificationService

    @State private var apiKeyInput: String = ""
    @State private var apiKeySaved: Bool = false
    @State private var apiKeyError: String?

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
                            Button("Save Key") {
                                let ok = Keychain.saveAPIKey(
                                    apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines),
                                    for: settings.aiProvider.keychainAccount)
                                if ok {
                                    apiKeyInput = ""
                                    apiKeySaved = true
                                    apiKeyError = nil
                                } else {
                                    apiKeyError = "Keychain refused to save. Make sure the app is code-signed (Xcode handles this when you Run)."
                                }
                            }
                            .buttonStyle(.borderedProminent).tint(Theme.systemCyan)

                            Button("Clear Key") {
                                Keychain.deleteAPIKey(for: settings.aiProvider.keychainAccount)
                                apiKeySaved = false
                                apiKeyError = nil
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
                        Button("Schedule") { notifications.scheduleDailyMorning(hour: settings.morningHour) }
                    }
                }

                SystemPanel("Danger Zone", tint: Theme.danger) {
                    Button("Reset Hunter (delete all data)") {
                        resetEverything()
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.danger)
                }
            }
            .padding(20)
        }
        .onAppear { refreshKeyState() }
        .onChange(of: settings.aiProviderRaw) { _, _ in refreshKeyState() }
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
