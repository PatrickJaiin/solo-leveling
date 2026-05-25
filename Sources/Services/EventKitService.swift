import Foundation
import EventKit
import AppKit

@MainActor
final class EventKitService {
    struct ScheduledEncounter: Identifiable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let calendarColor: NSColor?
    }

    private let store = EKEventStore()
    private(set) var authorized = false

    func requestAuthorization() async {
        do {
            if #available(macOS 14.0, *) {
                authorized = try await store.requestFullAccessToEvents()
            } else {
                authorized = try await store.requestAccess(to: .event)
            }
        } catch {
            authorized = false
        }
    }

    func todayEvents() -> [ScheduledEncounter] {
        guard authorized else { return [] }
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map { ev in
            ScheduledEncounter(id: ev.eventIdentifier ?? UUID().uuidString,
                               title: ev.title ?? "(untitled)",
                               start: ev.startDate,
                               end: ev.endDate,
                               calendarColor: ev.calendar?.color)
        }
    }
}
