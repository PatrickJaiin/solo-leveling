import Foundation

/// Secrets storage backed by `UserDefaults` (the app's private domain, sandboxed,
/// stored in the user's encrypted home directory).
///
/// Earlier versions used the macOS Keychain, but ad-hoc rebuilds change the binary's
/// signature, which makes the system prompt for the user's login password every time
/// the rebuilt app tries to read its own previously-saved item. For a single-user,
/// sandboxed personal app the Keychain hardening wasn't worth that friction — falling
/// back to UserDefaults is a deliberate trade-off.
///
/// The API name is kept (`Keychain.save/load/deleteAPIKey`) so callers don't change.
enum Keychain {
    private static let defaults = UserDefaults.standard

    enum Account: String, CaseIterable {
        case anthropic = "anthropic-api-key"
        case gemini = "gemini-api-key"

        var defaultsKey: String { "secret.\(rawValue)" }
    }

    @discardableResult
    static func saveAPIKey(_ key: String, for account: Account) -> Bool {
        defaults.set(key, forKey: account.defaultsKey)
        return true
    }

    static func loadAPIKey(for account: Account) -> String? {
        let v = defaults.string(forKey: account.defaultsKey)
        guard let v, !v.isEmpty else { return nil }
        return v
    }

    static func deleteAPIKey(for account: Account) {
        defaults.removeObject(forKey: account.defaultsKey)
    }
}
