import Foundation

public struct CalendarMonth {
    public let calendar: Calendar
    public let start: Date
    public let days: [Date?]

    public init?(containing date: Date, calendar: Calendar = .autoupdatingCurrent) {
        guard let interval = calendar.dateInterval(of: .month, for: date),
              let dayRange = calendar.range(of: .day, in: .month, for: date) else { return nil }
        let weekday = calendar.component(.weekday, from: interval.start)
        let leadingDays = (weekday - calendar.firstWeekday + 7) % 7
        var dates = [Date?](repeating: nil, count: leadingDays)
        for offset in 0..<dayRange.count {
            guard let day = calendar.date(byAdding: .day, value: offset, to: interval.start) else { return nil }
            dates.append(day)
        }
        let trailingDays = (7 - dates.count % 7) % 7
        dates.append(contentsOf: [Date?](repeating: nil, count: trailingDays))
        self.calendar = calendar
        start = interval.start
        days = dates
    }

    public var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let firstIndex = calendar.firstWeekday - 1
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }

    public var title: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .autoupdatingCurrent
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return formatter.string(from: start)
    }

    public func adjacentMonth(_ offset: Int) -> Date? {
        calendar.date(byAdding: .month, value: offset, to: start)
    }
}
