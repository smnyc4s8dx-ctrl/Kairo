import Foundation
import SwiftData

@Model
final class Wave {
    var startedAt: Date
    var plannedDuration: TimeInterval
    var endedAt: Date?
    var endReasonValue: String?
    var activeTask: TaskItem?
    var completedTaskAtEnd: Bool

    init(
        startedAt: Date = .now,
        plannedDuration: TimeInterval,
        activeTask: TaskItem? = nil
    ) {
        self.startedAt = startedAt
        self.plannedDuration = plannedDuration
        self.activeTask = activeTask
        self.completedTaskAtEnd = false
    }
}

extension Wave {
    var endReason: EndReason? {
        get { endReasonValue.flatMap(EndReason.init(rawValue:)) }
        set { endReasonValue = newValue?.rawValue }
    }

    enum EndReason: String, Codable {
        case elapsedComplete
        case elapsedCarryOver
        case endedEarlyComplete
        case skipped
        case cancelled
    }
}
