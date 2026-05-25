import Foundation
import SwiftUI

/// Lightweight observable wrapper around UserDefaults for app-level preferences.
@MainActor
@Observable
final class AppSettings {
    private let defaults = UserDefaults.standard

    var useAI: Bool {
        didSet { defaults.set(useAI, forKey: "useAI") }
    }
    var aiProviderRaw: String {
        didSet { defaults.set(aiProviderRaw, forKey: "aiProvider") }
    }
    var aiProvider: AIProvider {
        get { AIProvider(rawValue: aiProviderRaw) ?? .claude }
        set { aiProviderRaw = newValue.rawValue }
    }
    var useHealthKit: Bool {
        didSet { defaults.set(useHealthKit, forKey: "useHealthKit") }
    }
    var useCalendar: Bool {
        didSet { defaults.set(useCalendar, forKey: "useCalendar") }
    }
    var hudEnabled: Bool {
        didSet { defaults.set(hudEnabled, forKey: "hudEnabled") }
    }
    var morningHour: Int {
        didSet { defaults.set(morningHour, forKey: "morningHour") }
    }

    init() {
        // Register sensible defaults the first time the app launches.
        defaults.register(defaults: [
            "useAI": false,
            "aiProvider": AIProvider.claude.rawValue,
            "useHealthKit": false,
            "useCalendar": false,
            "hudEnabled": false,
            "morningHour": 8
        ])
        self.useAI = defaults.bool(forKey: "useAI")
        self.aiProviderRaw = defaults.string(forKey: "aiProvider") ?? AIProvider.claude.rawValue
        self.useHealthKit = defaults.bool(forKey: "useHealthKit")
        self.useCalendar = defaults.bool(forKey: "useCalendar")
        self.hudEnabled = defaults.bool(forKey: "hudEnabled")
        self.morningHour = defaults.integer(forKey: "morningHour")
    }
}
