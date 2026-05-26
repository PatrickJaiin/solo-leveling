import SwiftUI
import SwiftData
import AppKit

@main
@MainActor
struct SoloLevelingDailyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    // SwiftData container holds Hunter / Quest / Shadow / DailyLog / Fragment / BossEcho / Habit.
    // Safety net: if the store fails to load (schema bump without proper defaults), wipe and retry
    // rather than fatalError. We're not yet using VersionedSchema/MigrationPlan; for this single-
    // user personal app, last-resort wipe-and-retry is acceptable.
    let container: ModelContainer = {
        let schema = Schema([Hunter.self, Quest.self, Shadow.self, DailyLog.self,
                             Fragment.self, BossEcho.self, Habit.self])
        do {
            return try ModelContainer(for: schema)
        } catch {
            // Wipe the store and try once more. Existing user data is lost but the app boots.
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            if let storeURL = base?.appendingPathComponent("default.store") {
                try? FileManager.default.removeItem(at: storeURL)
                try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
                try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))
            }
            do {
                return try ModelContainer(for: schema)
            } catch {
                fatalError("ModelContainer init failed even after wipe: \(error)")
            }
        }
    }()

    @State private var settings: AppSettings
    @State private var engine: QuestEngine
    @State private var healthKit: HealthKitService
    @State private var eventKit: EventKitService
    @State private var notifications: NotificationService
    @State private var takeovers: SystemTakeoverCenter

    init() {
        let n = NotificationService()
        let c = ClaudeAPIService()
        let g = GeminiAPIService()
        let t = SystemTakeoverCenter()
        _settings = State(initialValue: AppSettings())
        _engine = State(initialValue: QuestEngine(claude: c, gemini: g, notifications: n, takeovers: t))
        _healthKit = State(initialValue: HealthKitService())
        _eventKit = State(initialValue: EventKitService())
        _notifications = State(initialValue: n)
        _takeovers = State(initialValue: t)
    }

    var body: some Scene {
        WindowGroup("Solo Leveling Daily") {
            MainWindowView(healthKit: healthKit, eventKit: eventKit, notifications: notifications)
                .frame(minWidth: 980, minHeight: 700)
                .environment(engine)
                .environment(settings)
                .environment(takeovers)
                .preferredColorScheme(.dark)
                .task {
                    await notifications.requestAuthorization()
                    delegate.attach(container: container, engine: engine, settings: settings)
                }
        }
        .modelContainer(container)
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .windowArrangement) {
                Button("Toggle Quest HUD") {
                    delegate.toggleHUD()
                }
                .keyboardShortcut("h", modifiers: [.command, .shift])
            }
        }
    }
}

/// AppDelegate owns the HUD window controller and bridges menu / lifecycle hooks.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hudController: HUDWindowController?
    private var container: ModelContainer?
    private var engine: QuestEngine?
    private var settings: AppSettings?

    @MainActor
    func attach(container: ModelContainer, engine: QuestEngine, settings: AppSettings) {
        self.container = container
        self.engine = engine
        self.settings = settings
        if settings.hudEnabled { showHUD() }
    }

    @MainActor
    func toggleHUD() {
        ensureController()
        hudController?.toggle()
    }

    @MainActor
    private func showHUD() {
        ensureController()
        hudController?.show()
    }

    @MainActor
    private func ensureController() {
        guard let container, let engine, let settings, hudController == nil else { return }
        hudController = HUDWindowController(modelContainer: container, engine: engine, settings: settings)
    }
}
