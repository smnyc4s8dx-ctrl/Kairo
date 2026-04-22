import Foundation
import SwiftData

@Model
final class TaskItem {
    var title: String
    var notes: String
    var priorityValue: Int
    var dueDate: Date?
    var isComplete: Bool
    var completedAt: Date?
    var createdAt: Date
    var carryOverCount: Int
    var recurrenceValue: String?
    var sortOrder: Int

    var parent: TaskItem?

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.parent)
    var children: [TaskItem] = []

    @Relationship(inverse: \Wave.activeTask)
    var waves: [Wave] = []

    init(
        title: String,
        notes: String = "",
        priority: Priority = .none,
        dueDate: Date? = nil,
        recurrence: Recurrence? = nil,
        parent: TaskItem? = nil,
        sortOrder: Int = 0
    ) {
        self.title = title
        self.notes = notes
        self.priorityValue = priority.rawValue
        self.dueDate = dueDate
        self.recurrenceValue = recurrence?.rawValue
        self.isComplete = false
        self.completedAt = nil
        self.createdAt = .now
        self.carryOverCount = 0
        self.parent = parent
        self.sortOrder = sortOrder
    }
}

extension TaskItem {
    var priority: Priority {
        get { Priority(rawValue: priorityValue) ?? .none }
        set { priorityValue = newValue.rawValue }
    }

    var recurrence: Recurrence? {
        get { recurrenceValue.flatMap(Recurrence.init(rawValue:)) }
        set { recurrenceValue = newValue?.rawValue }
    }

    enum Priority: Int, CaseIterable, Codable, Identifiable {
        case none = 0, low = 1, medium = 2, high = 3
        var id: Int { rawValue }

        var label: String {
            switch self {
            case .none: "None"; case .low: "Low"; case .medium: "Medium"; case .high: "High"
            }
        }

        var symbol: String {
            switch self {
            case .none: "circle"
            case .low: "chevron.down"
            case .medium: "equal"
            case .high: "chevron.up.2"
            }
        }
    }

    enum Recurrence: String, CaseIterable, Codable, Identifiable {
        case daily, weekdays, weekends, weekly, monthly
        var id: String { rawValue }

        var label: String {
            switch self {
            case .daily: "Every day"
            case .weekdays: "Weekdays"
            case .weekends: "Weekends"
            case .weekly: "Every week"
            case .monthly: "Every month"
            }
        }

        func contextualLabel(dueDate: Date?) -> String {
            if case .weekly = self, let dueDate {
                let fmt = DateFormatter()
                fmt.dateFormat = "EEEE"
                return "Every \(fmt.string(from: dueDate))"
            }
            return label
        }
    }

    var sortedChildren: [TaskItem] {
        children.sorted { $0.sortOrder < $1.sortOrder }
    }

    var hasChildren: Bool { !children.isEmpty }

    var completedChildCount: Int {
        children.filter(\.isComplete).count
    }

    /// Set completion state and optionally cascade to children.
    /// Cascading only runs on completion → true, never on uncheck (destructive to un-complete children silently).
    func setComplete(_ value: Bool, cascadeChildren: Bool = true) {
        isComplete = value
        completedAt = value ? .now : nil
        if value && cascadeChildren {
            for child in children where !child.isComplete {
                child.isComplete = true
                child.completedAt = .now
            }
        }
    }

    func nextRecurrenceDueDate(basis: Date = .now) -> Date? {
        guard let recurrence else { return nil }
        let cal = Calendar.current
        let base = dueDate ?? basis
        switch recurrence {
        case .daily:
            return cal.date(byAdding: .day, value: 1, to: base)
        case .weekdays:
            var d = cal.date(byAdding: .day, value: 1, to: base) ?? base
            while let wd = cal.dateComponents([.weekday], from: d).weekday, wd == 1 || wd == 7 {
                d = cal.date(byAdding: .day, value: 1, to: d) ?? d
            }
            return d
        case .weekends:
            var d = cal.date(byAdding: .day, value: 1, to: base) ?? base
            while let wd = cal.dateComponents([.weekday], from: d).weekday, wd != 1 && wd != 7 {
                d = cal.date(byAdding: .day, value: 1, to: d) ?? d
            }
            return d
        case .weekly:
            return cal.date(byAdding: .weekOfYear, value: 1, to: base)
        case .monthly:
            return cal.date(byAdding: .month, value: 1, to: base)
        }
    }
}

