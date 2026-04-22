import Foundation

#if os(iOS)
import ActivityKit

@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()
    private var activity: Activity<KairoActivityAttributes>?

    private init() {}

    func start(phaseLabel: String, endDate: Date, activeTask: String?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endCurrent()
        let attrs = KairoActivityAttributes(startedAt: .now)
        let state = KairoActivityAttributes.ContentState(
            phaseLabel: phaseLabel,
            endDate: endDate,
            activeTaskTitle: activeTask,
            isPaused: false
        )
        let content = ActivityContent(state: state, staleDate: endDate.addingTimeInterval(60))
        activity = try? Activity.request(attributes: attrs, content: content, pushType: nil)
    }

    func update(phaseLabel: String, endDate: Date, activeTask: String?, isPaused: Bool) {
        guard let activity else { return }
        let state = KairoActivityAttributes.ContentState(
            phaseLabel: phaseLabel,
            endDate: endDate,
            activeTaskTitle: activeTask,
            isPaused: isPaused
        )
        let content = ActivityContent(state: state, staleDate: endDate.addingTimeInterval(60))
        Task { await activity.update(content) }
    }

    func endCurrent() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
#else

@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()
    private init() {}
    func start(phaseLabel: String, endDate: Date, activeTask: String?) {}
    func update(phaseLabel: String, endDate: Date, activeTask: String?, isPaused: Bool) {}
    func endCurrent() {}
}
#endif
