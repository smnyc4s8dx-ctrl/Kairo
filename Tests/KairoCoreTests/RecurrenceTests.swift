import XCTest
import SwiftData
@testable import KairoCore

@MainActor
final class RecurrenceTests: XCTestCase {

    // April 24, 2026 is a Friday.
    private static let friday = Calendar.current.date(
        from: DateComponents(year: 2026, month: 4, day: 24)
    )!

    // MARK: - nextRecurrenceDueDate (no container — @Model is instantiable standalone)

    func testDailyAddsOneDay() throws {
        let task = TaskItem(title: "T", dueDate: Self.friday, recurrence: .daily)
        let next = try XCTUnwrap(task.nextRecurrenceDueDate())
        let expected = Calendar.current.date(byAdding: .day, value: 1, to: Self.friday)!
        XCTAssertEqual(next, expected)
    }

    func testWeeklyPreservesDayOfWeek() throws {
        let task = TaskItem(title: "T", dueDate: Self.friday, recurrence: .weekly)
        let next = try XCTUnwrap(task.nextRecurrenceDueDate())
        let cal = Calendar.current
        XCTAssertEqual(
            cal.component(.weekday, from: next),
            cal.component(.weekday, from: Self.friday)
        )
        XCTAssertEqual(cal.dateComponents([.day], from: Self.friday, to: next).day, 7)
    }

    func testWeekdaysSkipsWeekends() throws {
        // Friday + 1 weekday → Monday (skip Sat/Sun).
        let task = TaskItem(title: "T", dueDate: Self.friday, recurrence: .weekdays)
        let next = try XCTUnwrap(task.nextRecurrenceDueDate())
        let weekday = Calendar.current.component(.weekday, from: next)
        XCTAssertEqual(weekday, 2, "Expected Monday (weekday=2)")
    }

    func testWeekendsLandsOnWeekend() throws {
        let task = TaskItem(title: "T", dueDate: Self.friday, recurrence: .weekends)
        let next = try XCTUnwrap(task.nextRecurrenceDueDate())
        let weekday = Calendar.current.component(.weekday, from: next)
        XCTAssertTrue(weekday == 1 || weekday == 7, "Expected Sat/Sun, got \(weekday)")
    }

    func testMonthlyAddsOneMonthPreservingDay() throws {
        let task = TaskItem(title: "T", dueDate: Self.friday, recurrence: .monthly)
        let next = try XCTUnwrap(task.nextRecurrenceDueDate())
        let cal = Calendar.current
        let expected = cal.date(byAdding: .month, value: 1, to: Self.friday)!
        XCTAssertEqual(next, expected)
        XCTAssertEqual(
            cal.component(.day, from: next),
            cal.component(.day, from: Self.friday)
        )
    }

    func testNextRecurrenceDueDateNilWhenNoRecurrence() throws {
        let task = TaskItem(title: "T", dueDate: Self.friday)
        XCTAssertNil(task.nextRecurrenceDueDate())
    }

    // MARK: - contextualLabel (pure enum method, no SwiftData)

    func testContextualLabelWeeklyWithDueDate() {
        XCTAssertEqual(
            TaskItem.Recurrence.weekly.contextualLabel(dueDate: Self.friday),
            "Every Friday"
        )
    }

    func testContextualLabelWeeklyNilDueDate() {
        XCTAssertEqual(
            TaskItem.Recurrence.weekly.contextualLabel(dueDate: nil),
            "Every week"
        )
    }

    func testContextualLabelNonWeeklyIgnoresDueDate() {
        XCTAssertEqual(
            TaskItem.Recurrence.daily.contextualLabel(dueDate: Self.friday),
            "Every day"
        )
        XCTAssertEqual(
            TaskItem.Recurrence.monthly.contextualLabel(dueDate: Self.friday),
            "Every month"
        )
        XCTAssertEqual(
            TaskItem.Recurrence.weekdays.contextualLabel(dueDate: Self.friday),
            "Weekdays"
        )
        XCTAssertEqual(
            TaskItem.Recurrence.weekends.contextualLabel(dueDate: Self.friday),
            "Weekends"
        )
    }
}
