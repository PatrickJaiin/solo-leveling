import Foundation

enum DayKey {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(for date: Date = Date()) -> String { formatter.string(from: date) }

    static func date(from key: String) -> Date? { formatter.date(from: key) }

    static func yesterday(of date: Date = Date()) -> String {
        let prev = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        return key(for: prev)
    }

    static func isSunday(_ date: Date = Date()) -> Bool {
        Calendar.current.component(.weekday, from: date) == 1
    }
}
