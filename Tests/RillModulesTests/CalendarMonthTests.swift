import Foundation
import XCTest

final class CalendarMonthTests: XCTestCase {
    func testLeapMonthContainsEveryDayAndHonorsMondayWeekStart() throws {
        let calendar = try makeCalendar(firstWeekday: 2)
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 2, day: 15)))
        let month = try XCTUnwrap(CalendarMonth(containing: date, calendar: calendar))
        let days = month.days.compactMap { $0 }
        XCTAssertEqual(days.map { calendar.component(.day, from: $0) }, Array(1...29))
        XCTAssertEqual(month.days.prefix(while: { $0 == nil }).count, 3)
        XCTAssertEqual(month.days.count % 7, 0)
        XCTAssertEqual(month.weekdaySymbols.first, calendar.shortStandaloneWeekdaySymbols[1])
        XCTAssertTrue(days.allSatisfy { calendar.component(.month, from: $0) == 2 })
    }

    func testSundayWeekStartChangesLeadingCellsWithoutChangingDays() throws {
        let calendar = try makeCalendar(firstWeekday: 1)
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 2, day: 15)))
        let month = try XCTUnwrap(CalendarMonth(containing: date, calendar: calendar))
        XCTAssertEqual(month.days.prefix(while: { $0 == nil }).count, 4)
        XCTAssertEqual(month.days.compactMap { $0 }.count, 29)
        XCTAssertEqual(month.weekdaySymbols.first, calendar.shortStandaloneWeekdaySymbols[0])
    }

    func testMonthNavigationStartsAtFirstDayAcrossYearBoundary() throws {
        let calendar = try makeCalendar(firstWeekday: 2)
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 12, day: 31)))
        let month = try XCTUnwrap(CalendarMonth(containing: date, calendar: calendar))
        let next = try XCTUnwrap(month.adjacentMonth(1))
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: next), DateComponents(year: 2025, month: 1, day: 1))
        let nextMonth = try XCTUnwrap(CalendarMonth(containing: next, calendar: calendar))
        XCTAssertEqual(nextMonth.adjacentMonth(-1), month.start)
    }

    func testDaylightSavingTransitionRetainsLocalDates() throws {
        let calendar = try makeCalendar(firstWeekday: 1)
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 3, day: 15)))
        let month = try XCTUnwrap(CalendarMonth(containing: date, calendar: calendar))
        let days = month.days.compactMap { $0 }
        XCTAssertEqual(days.map { calendar.component(.day, from: $0) }, Array(1...31))
        XCTAssertTrue(days.allSatisfy { calendar.component(.hour, from: $0) == 0 })
        XCTAssertEqual(days[10].timeIntervalSince(days[9]), 23 * 60 * 60)
    }

    func testMonthTitleUsesCalendarLocale() throws {
        var calendar = try makeCalendar(firstWeekday: 2)
        calendar.locale = Locale(identifier: "fr_FR")
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 2, day: 15)))
        let month = try XCTUnwrap(CalendarMonth(containing: date, calendar: calendar))
        XCTAssertTrue(month.title.contains("février"))
        XCTAssertTrue(month.title.contains("2024"))
        XCTAssertEqual(month.weekdaySymbols.first, calendar.shortStandaloneWeekdaySymbols[1])
    }

    func testHebrewLeapYearIncludesBothAdarMonths() throws {
        var calendar = Calendar(identifier: .hebrew)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Jerusalem"))
        calendar.locale = Locale(identifier: "he_IL")
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 5784, month: 6, day: 15)))
        let firstAdar = try XCTUnwrap(CalendarMonth(containing: date, calendar: calendar))
        let firstDays = firstAdar.days.compactMap { $0 }
        XCTAssertEqual(firstDays.map { calendar.component(.day, from: $0) }, Array(1...30))
        XCTAssertTrue(firstDays.allSatisfy { calendar.component(.month, from: $0) == 6 })
        let next = try XCTUnwrap(firstAdar.adjacentMonth(1))
        let secondAdar = try XCTUnwrap(CalendarMonth(containing: next, calendar: calendar))
        let secondDays = secondAdar.days.compactMap { $0 }
        XCTAssertEqual(secondDays.map { calendar.component(.day, from: $0) }, Array(1...29))
        XCTAssertTrue(secondDays.allSatisfy { calendar.component(.month, from: $0) == 7 })
        XCTAssertEqual(secondAdar.adjacentMonth(-1), firstAdar.start)
    }

    private func makeCalendar(firstWeekday: Int) throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        calendar.locale = Locale(identifier: "en_US")
        calendar.firstWeekday = firstWeekday
        return calendar
    }
}
