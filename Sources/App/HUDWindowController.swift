import AppKit
import SwiftUI
import SwiftData

/// Hosts the floating quest HUD in a borderless, always-on-top, non-activating panel.
///
/// The HUD looks up its Hunter via @Query inside HUDOverlayView so it never holds a managed
/// object from a foreign ModelContext — mutations stay coherent with the main window's store.
@MainActor
final class HUDWindowController {
    private var panel: NSPanel?
    private let modelContainer: ModelContainer
    private let engine: QuestEngine
    private let settings: AppSettings

    init(modelContainer: ModelContainer, engine: QuestEngine, settings: AppSettings) {
        self.modelContainer = modelContainer
        self.engine = engine
        self.settings = settings
    }

    func show() {
        if panel == nil {
            let host = NSHostingView(rootView:
                HUDOverlayView()
                    .environment(engine)
                    .modelContainer(modelContainer)
            )
            let style: NSWindow.StyleMask = [.borderless, .nonactivatingPanel, .resizable]
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 220),
                            styleMask: style, backing: .buffered, defer: false)
            p.isFloatingPanel = true
            p.level = .floating
            p.collectionBehavior = [.canJoinAllSpaces, .stationary]
            p.backgroundColor = .clear
            p.isOpaque = false
            p.hasShadow = true
            p.hidesOnDeactivate = false
            p.isMovableByWindowBackground = true
            p.contentView = host
            if let screen = NSScreen.main {
                let frame = screen.visibleFrame
                p.setFrameOrigin(NSPoint(x: frame.maxX - 340, y: frame.maxY - 240))
            }
            panel = p
        }
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggle() {
        if let p = panel, p.isVisible { hide() } else { show() }
    }
}
