import Foundation

#if os(iOS)
import ActivityKit

struct KairoActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var phaseLabel: String
        var endDate: Date
        var activeTaskTitle: String?
        var isPaused: Bool
    }

    var startedAt: Date
}
#endif
