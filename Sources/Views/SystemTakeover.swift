import SwiftUI

/// Brief full-screen overlay messages — the "System Window" aesthetic.
/// Posted by services when something dramatic happens; auto-dismisses after a short window.
@MainActor
@Observable
final class SystemTakeoverCenter {
    var current: TakeoverMessage?
    private var queue: [TakeoverMessage] = []
    private var dismissTask: Task<Void, Never>?

    func post(_ msg: TakeoverMessage) {
        if current == nil {
            present(msg)
        } else {
            queue.append(msg)
        }
    }

    private func present(_ msg: TakeoverMessage) {
        current = msg
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(msg.duration * 1_000_000_000))
            guard let self else { return }
            if self.current?.id == msg.id {
                self.current = nil
                if let next = self.queue.first {
                    self.queue.removeFirst()
                    self.present(next)
                }
            }
        }
    }

    func dismissCurrent() {
        current = nil
        dismissTask?.cancel()
        if let next = queue.first {
            queue.removeFirst()
            present(next)
        }
    }
}

struct TakeoverMessage: Identifiable, Equatable {
    let id: UUID = UUID()
    let header: String                    // "[ DROP — RARE ]"
    let title: String                     // "Codex of the Diligent"
    let body: String?                     // 1-line flavor
    let tint: Color
    let duration: TimeInterval

    static func fragmentDrop(_ f: Fragment) -> TakeoverMessage {
        TakeoverMessage(header: "[ DROP — \(f.rarity.label) ]",
                        title: f.title,
                        body: f.detail,
                        tint: f.rarity.tint,
                        duration: f.rarity == .epic ? 4.0 : 2.5)
    }

    static func bossSpawn(_ e: BossEcho) -> TakeoverMessage {
        TakeoverMessage(header: "[ ECHO MANIFESTED ]",
                        title: e.name,
                        body: e.flavor,
                        tint: Theme.danger,
                        duration: 4.5)
    }

    static func bossKilled(_ e: BossEcho) -> TakeoverMessage {
        TakeoverMessage(header: "[ ECHO DISPATCHED ]",
                        title: "\(e.name) collapses.",
                        body: "The System adds it to your Shadow Army.",
                        tint: Theme.systemCyan,
                        duration: 3.5)
    }

    static func questsIssued(count: Int, isPenalty: Bool) -> TakeoverMessage {
        TakeoverMessage(header: isPenalty ? "[ PENALTY ZONE ]" : "[ DAILY QUESTS ISSUED ]",
                        title: "\(count) quests assigned",
                        body: isPenalty ? "The System has escalated. Clear ≥50% to restore standing." : nil,
                        tint: isPenalty ? Theme.danger : Theme.systemCyan,
                        duration: 2.0)
    }

    static func restDecreed() -> TakeoverMessage {
        TakeoverMessage(header: "[ REST DECREED ]",
                        title: "The System withdraws.",
                        body: "No debt today. The streak survives.",
                        tint: Theme.systemGold,
                        duration: 2.5)
    }
}

struct SystemTakeoverView: View {
    let message: TakeoverMessage
    let onDismiss: () -> Void

    @State private var visible = false

    var body: some View {
        ZStack {
            // Subtle dimming — not full opaque; lets the user keep working.
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack {
                SystemPanel(tint: message.tint, notch: 14, padding: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(message.header)
                            .font(Typography.mono(12, weight: .heavy))
                            .foregroundStyle(message.tint)
                            .glow(message.tint, radius: 4, intensity: 0.7)
                        Text(message.title)
                            .font(Typography.mono(22, weight: .black))
                            .foregroundStyle(.white)
                        if let body = message.body {
                            Text(body)
                                .font(Typography.body)
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(3)
                        }
                    }
                    .frame(maxWidth: 520, alignment: .leading)
                }
                .padding(.top, 60)
                .scaleEffect(visible ? 1.0 : 0.92)
                .opacity(visible ? 1.0 : 0.0)
                .glow(message.tint, radius: 12, intensity: 0.4)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                visible = true
            }
        }
    }
}
