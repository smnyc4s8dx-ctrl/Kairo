import XCTest
import SwiftData
@testable import KairoCore

/// These tests exercise `TaskItem`'s behavior *without* a `ModelContainer`.
/// SwiftData's `@Model` classes can be instantiated and have their computed
/// properties exercised standalone; we manually wire the parent/children
/// relationship rather than relying on context inverse-inference.
@MainActor
final class TaskItemTests: XCTestCase {

    /// Builds a parent with N children whose `parent` reference is set via init
    /// and whose `children` array is manually populated (mirroring what
    /// SwiftData would do under a container).
    private func makeParent(withChildren count: Int) -> (parent: TaskItem, children: [TaskItem]) {
        let parent = TaskItem(title: "Parent")
        let children: [TaskItem] = (0..<count).map { i in
            TaskItem(title: "Child \(i)", parent: parent, sortOrder: i)
        }
        parent.children = children
        return (parent, children)
    }

    // MARK: - setComplete / cascade

    func testSetCompleteCascadesToChildren() {
        let (parent, children) = makeParent(withChildren: 2)

        let cascaded = parent.setComplete(true)

        XCTAssertTrue(parent.isComplete)
        XCTAssertNotNil(parent.completedAt)
        XCTAssertTrue(children[0].isComplete)
        XCTAssertTrue(children[1].isComplete)
        XCTAssertEqual(cascaded.count, 2)
    }

    func testSetCompleteSkipsAlreadyCompleteChildren() {
        let (parent, children) = makeParent(withChildren: 2)
        children[0].isComplete = true
        children[0].completedAt = .now

        let cascaded = parent.setComplete(true)

        XCTAssertEqual(cascaded.count, 1, "Only the not-yet-complete child should be in the cascaded list")
    }

    func testSetCompleteFalsePreservesChildren() {
        let (parent, children) = makeParent(withChildren: 1)
        parent.isComplete = true
        parent.completedAt = .now
        children[0].isComplete = true
        children[0].completedAt = .now

        let cascaded = parent.setComplete(false)

        XCTAssertFalse(parent.isComplete)
        XCTAssertNil(parent.completedAt)
        XCTAssertTrue(children[0].isComplete, "Children must not be silently uncompleted")
        XCTAssertNotNil(children[0].completedAt)
        XCTAssertTrue(cascaded.isEmpty)
    }

    func testSetCompleteWithCascadeChildrenFalseLeavesChildrenAlone() {
        let (parent, children) = makeParent(withChildren: 1)

        let cascaded = parent.setComplete(true, cascadeChildren: false)

        XCTAssertTrue(parent.isComplete)
        XCTAssertFalse(children[0].isComplete)
        XCTAssertTrue(cascaded.isEmpty)
    }

    // MARK: - Sorting / counts

    func testSortedChildrenOrdersBySortOrder() {
        let parent = TaskItem(title: "P")
        let a = TaskItem(title: "A", parent: parent, sortOrder: 2)
        let b = TaskItem(title: "B", parent: parent, sortOrder: 0)
        let c = TaskItem(title: "C", parent: parent, sortOrder: 1)
        parent.children = [a, b, c]

        XCTAssertEqual(parent.sortedChildren.map(\.title), ["B", "C", "A"])
    }

    func testCompletedChildCountCountsOnlyComplete() {
        let (parent, children) = makeParent(withChildren: 3)
        children[0].isComplete = true
        children[2].isComplete = true

        XCTAssertEqual(parent.completedChildCount, 2)
        XCTAssertEqual(parent.children.count, 3)
        XCTAssertTrue(parent.hasChildren)
    }

    func testLeafHasNoChildren() {
        let t = TaskItem(title: "Solo")
        XCTAssertFalse(t.hasChildren)
        XCTAssertEqual(t.completedChildCount, 0)
    }

    // MARK: - Raw-value round-trips

    func testPriorityRoundTripsThroughRawValue() {
        let t = TaskItem(title: "T", priority: .high)
        XCTAssertEqual(t.priority, .high)
        XCTAssertEqual(t.priorityValue, TaskItem.Priority.high.rawValue)
        t.priority = .low
        XCTAssertEqual(t.priorityValue, TaskItem.Priority.low.rawValue)
    }

    func testRecurrenceRoundTripsThroughRawValue() {
        let t = TaskItem(title: "T", recurrence: .weekly)
        XCTAssertEqual(t.recurrence, .weekly)
        t.recurrence = nil
        XCTAssertNil(t.recurrenceValue)
        t.recurrence = .monthly
        XCTAssertEqual(t.recurrenceValue, TaskItem.Recurrence.monthly.rawValue)
    }

    // MARK: - Defaults

    func testNewTaskItemDefaults() {
        let t = TaskItem(title: "Fresh")
        XCTAssertEqual(t.title, "Fresh")
        XCTAssertFalse(t.isComplete)
        XCTAssertNil(t.completedAt)
        XCTAssertEqual(t.priority, .none)
        XCTAssertNil(t.dueDate)
        XCTAssertNil(t.recurrence)
        XCTAssertEqual(t.carryOverCount, 0)
        XCTAssertNil(t.parent)
        XCTAssertEqual(t.sortOrder, 0)
        XCTAssertTrue(t.notes.isEmpty)
    }
}
