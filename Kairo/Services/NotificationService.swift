import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let waveEndID = "kairo.wave.end"
    private let breakEndID = "kairo.break.end"

    private init() {}

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func scheduleWaveEnd(fireAt date: Date, taskTitle: String?) {
        let content = UNMutableNotificationContent()
        content.title = "Wave complete"
        content.body = taskTitle.map { "Wrap up on \"\($0)\" — time for a break." }
            ?? "Nice focus — time for a break."
        content.sound = .default
        schedule(content, fireAt: date, id: waveEndID)
    }

    func scheduleBreakEnd(fireAt date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Break over"
        content.body = "Ready for the next wave?"
        content.sound = .default
        schedule(content, fireAt: date, id: breakEndID)
    }

    func cancelAll() {
        center.removePendingNotificationRequests(
            withIdentifiers: [waveEndID, breakEndID]
        )
    }

    private func schedule(_ content: UNMutableNotificationContent, fireAt date: Date, id: String) {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.add(req)
    }
}
