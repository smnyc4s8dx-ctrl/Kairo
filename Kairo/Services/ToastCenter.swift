import Foundation
import Observation

@Observable
@MainActor
final class ToastCenter {
    static let shared = ToastCenter()

    struct Toast: Identifiable {
        let id: UUID = UUID()
        let message: String
        var actionLabel: String?
        var action: (() -> Void)?
    }

    private(set) var current: Toast?
    private var dismissTask: Task<Void, Never>?

    private init() {}

    func show(
        _ message: String,
        actionLabel: String? = nil,
        duration: Duration = .seconds(4),
        action: (() -> Void)? = nil
    ) {
        dismissTask?.cancel()
        current = Toast(message: message, actionLabel: actionLabel, action: action)
        let token = current?.id
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: duration)
            await MainActor.run {
                if self?.current?.id == token {
                    self?.current = nil
                }
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        current = nil
    }
}
