import SwiftUI

struct CalendarPopover: View {
    let now: Date
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    @State private var displayedDate: Date

    init(now: Date) {
        self.now = now
        _displayedDate = State(initialValue: now)
    }

    private var calendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.locale = locale
        calendar.timeZone = timeZone
        return calendar
    }

    var body: some View {
        VStack(spacing: 12) {
            if let month = CalendarMonth(containing: displayedDate, calendar: calendar) {
                monthHeader(month)
                monthGrid(month)
                Button("Today") { displayedDate = now }
                    .accessibilityHint("Shows the current month")
            } else {
                Text("Calendar unavailable")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func monthHeader(_ month: CalendarMonth) -> some View {
        HStack {
            Button {
                if let previous = month.adjacentMonth(-1) { displayedDate = previous }
            } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Previous month")
            .disabled(month.adjacentMonth(-1) == nil)
            Spacer()
            Text(month.title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button {
                if let next = month.adjacentMonth(1) { displayedDate = next }
            } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("Next month")
            .disabled(month.adjacentMonth(1) == nil)
        }
    }

    private func monthGrid(_ month: CalendarMonth) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
            ForEach(Array(month.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 24)
                    .accessibilityHidden(true)
            }
            ForEach(Array(month.days.enumerated()), id: \.offset) { _, date in
                if let date {
                    dayLabel(date, calendar: month.calendar)
                } else {
                    Color.clear
                        .frame(height: 30)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func dayLabel(_ date: Date, calendar: Calendar) -> some View {
        let isToday = calendar.isDate(date, inSameDayAs: now)
        let dateFormat = Date.FormatStyle(date: .complete, time: .omitted,
                                         locale: calendar.locale ?? locale, calendar: calendar, timeZone: calendar.timeZone)
        return Text(calendar.component(.day, from: date), format: .number)
            .fontWeight(isToday ? .bold : .regular)
            .frame(width: 30, height: 30)
            .background {
                if isToday {
                    Circle().fill(Color.accentColor.opacity(0.2))
                }
            }
            .accessibilityLabel(Text(date, format: dateFormat))
            .accessibilityValue(isToday ? "Today" : "")
    }
}
