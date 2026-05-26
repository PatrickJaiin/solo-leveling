import SwiftUI
import SwiftData

enum MainTab: String, CaseIterable, Identifiable {
    case quests = "Quests"
    case stats = "Stats"
    case shadows = "Shadows"
    case settings = "Settings"
    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .quests: "checklist"
        case .stats: "chart.bar.fill"
        case .shadows: "figure.stand.line.dotted.figure.stand"
        case .settings: "gearshape.fill"
        }
    }
}

struct MainWindowView: View {
    @Environment(\.modelContext) private var context
    @Environment(QuestEngine.self) private var engine
    @Environment(AppSettings.self) private var settings
    @Environment(SystemTakeoverCenter.self) private var takeovers
    let healthKit: HealthKitService
    let eventKit: EventKitService
    let notifications: NotificationService

    @Query private var hunters: [Hunter]
    @State private var tab: MainTab = .quests
    @State private var showingLevelUp: Bool = false
    @State private var showingStatusWindow: Bool = false
    @State private var initializing: Bool = false

    var body: some View {
        ZStack {
            Theme.bgGradient.ignoresSafeArea()
            if let hunter = hunters.first {
                NavigationSplitView {
                    sidebar
                } detail: {
                    detail(for: hunter)
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                ProgressView("Initialising the System…")
                    .font(Typography.body).foregroundStyle(Theme.systemCyan)
                    .task { await initializeHunter() }
            }

            if showingLevelUp, let result = engine.lastLevelUp {
                LevelUpModal(result: result) {
                    showingLevelUp = false
                    engine.lastLevelUp = nil
                    if let hunter = hunters.first, hunter.unspentPoints > 0 {
                        showingStatusWindow = true
                    }
                }
                .transition(.opacity.combined(with: .scale))
                .zIndex(10)
            }

            if showingStatusWindow, let hunter = hunters.first {
                StatusWindowView(hunter: hunter) { showingStatusWindow = false }
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(11)
            }

            if let msg = takeovers.current {
                SystemTakeoverView(message: msg) { takeovers.dismissCurrent() }
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .onChange(of: engine.lastLevelUp?.id) { _, new in
            if new != nil { showingLevelUp = true }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("[ SYSTEM ]")
                .font(Typography.systemTag)
                .foregroundStyle(Theme.systemCyan)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)
            ForEach(MainTab.allCases) { t in
                Button { tab = t } label: {
                    HStack(spacing: 10) {
                        Image(systemName: t.systemImage)
                            .frame(width: 18)
                        Text(t.rawValue)
                        Spacer(minLength: 0)
                    }
                    .font(Typography.body)
                    .foregroundStyle(tab == t ? Theme.systemCyan : .white.opacity(0.85))
                    .padding(.vertical, 7)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(tab == t ? Theme.systemBlue.opacity(0.18) : .clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }
            Spacer()
        }
        .background(Theme.bg)
        .frame(minWidth: 180)
    }

    @ViewBuilder
    private func detail(for hunter: Hunter) -> some View {
        VStack(spacing: 0) {
            HunterBanner(hunter: hunter, onOpenStatus: { showingStatusWindow = true })
                .padding([.top, .horizontal], 20)
                .padding(.bottom, 12)
            switch tab {
            case .quests:
                QuestBoardView(hunter: hunter, eventKit: eventKit, healthKit: healthKit)
            case .stats:
                StatSheetView(hunter: hunter)
            case .shadows:
                ShadowArmyView()
            case .settings:
                SettingsView(hunter: hunter, healthKit: healthKit, eventKit: eventKit, notifications: notifications)
            }
        }
        .frame(minWidth: 720, minHeight: 600)
    }

    private func initializeHunter() async {
        guard !initializing, hunters.isEmpty else { return }
        initializing = true
        let h = Hunter()
        context.insert(h)
        try? context.save()
        initializing = false
    }
}
