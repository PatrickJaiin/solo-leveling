import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    enum Kind {
        case alert
        case scheduled(date: Date, repeats: Bool)
    }

    private let center = UNUserNotificationCenter.current()
    private(set) var authorized: Bool = false

    func requestAuthorization() async {
        do {
            authorized = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            authorized = false
        }
    }

    /// Post an immediate "[System]" alert.
    func post(_ kind: Kind, title: String, body: String, soundName: String = "Glass") {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
        let trigger: UNNotificationTrigger?
        switch kind {
        case .alert:
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        case .scheduled(let date, let repeats):
            let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
            trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: repeats)
        }
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        center.add(req)
    }

    /// Schedule a daily morning reminder at the given hour.
    func scheduleDailyMorning(hour: Int = 8, minute: Int = 0) {
        let content = UNMutableNotificationContent()
        content.title = "[ SYSTEM ]"
        content.body = "A new day. Your quests await."
        content.sound = UNNotificationSound(named: UNNotificationSoundName("Glass"))
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let req = UNNotificationRequest(identifier: "daily-morning",
                                         content: content, trigger: trigger)
        center.removePendingNotificationRequests(withIdentifiers: ["daily-morning"])
        center.add(req)
    }
}
