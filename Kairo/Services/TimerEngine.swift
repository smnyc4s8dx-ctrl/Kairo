import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TimerEngine {
    enum Phase: Equatable {
        case idle
        case focus
        case awaitingEndDecision
        case shortBreak
        case longBreak
    }

    private(set) var phase: Phase = .idle
    private(set) var endDate: Date?
    private(set) var pausedRemaining: TimeInterval?
    private(set) var completedFocusWavesInCycle: Int = 0
    private(set) var currentWave: Wave?
    var activeTask: TaskItem?

    private var elapsedTask: Task<Void, Never>?
    private let modelContext: ModelContext
    private let settings: AppSettings
    private let notifications: NotificationService

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.settings = AppSettings.shared
        self.notifications = NotificationService.shared
    }

    // MARK: - Derived state

    var isPaused: Bool { pausedRemaining != nil }
    var isRunning: Bool { endDate != nil && !isPaused }

    var remaining: TimeInterval {
        if let pausedRemaining { return pausedRemaining }
        guard let endDate else { return totalForPhase }
        return max(0, endDate.timeIntervalSinceNow)
    }

    var totalForPhase: TimeInterval {
        switch phase {
        case .focus, .awaitingEndDecision: TimeInterval(settings.focusDurationMinutes) * 60
        case .shortBreak: TimeInterval(settings.shortBreakMinutes) * 60
        case .longBreak: TimeInterval(settings.longBreakMinutes) * 60
        case .idle: TimeInterval(settings.focusDurationMinutes) * 60
        }
    }

    var progress: Double {
        guard totalForPhase > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / totalForPhase))
    }

    // MARK: - User actions

    func startFocus(with task: TaskItem? = nil) {
        cancelTimer()
        activeTask = task
        let duration = TimeInterval(settings.focusDurationMinutes) * 60
        let end = Date().addingTimeInterval(duration)
        let wave = Wave(startedAt: .now, plannedDuration: duration, activeTask: task)
        modelContext.insert(wave)
        try? modelContext.save()
        currentWave = wave
        phase = .focus
        pausedRemaining = nil
        endDate = end
        scheduleElapsedDispatch()
        if settings.notificationsEnabled {
            notifications.scheduleWaveEnd(fireAt: end, taskTitle: task?.title)
        }
    }

    func pause() {
        guard let endDate, pausedRemaining == nil else { return }
        pausedRemaining = max(0, endDate.timeIntervalSinceNow)
        self.endDate = nil
        elapsedTask?.cancel()
        notifications.cancelAll()
    }

    func resume() {
        guard let pausedRemaining else { return }
        let end = Date().addingTimeInterval(pausedRemaining)
        endDate = end
        self.pausedRemaining = nil
        scheduleElapsedDispatch()
        if phase == .focus, settings.notificationsEnabled {
            notifications.scheduleWaveEnd(fireAt: end, taskTitle: activeTask?.title)
        } else if (phase == .shortBreak || phase == .longBreak), settings.notificationsEnabled {
            notifications.scheduleBreakEnd(fireAt: end)
        }
    }

    func skip() {
        switch phase {
        case .focus:
            cancelTimer()
            notifications.cancelAll()
            closeCurrentWave(reason: .skipped, completedTask: false)
            // Skipped focus doesn't count toward long-break cadence — user didn't do the work.
            activeTask = nil
            currentWave = nil
            enterBreak()
        case .shortBreak, .longBreak:
            cancelTimer()
            if settings.autoStartNextWave {
                startFocus(with: nil)
            } else {
                phase = .idle
                endDate = nil
                pausedRemaining = nil
            }
        case .awaitingEndDecision, .idle:
            break
        }
    }

    func endFocusEarlyComplete() {
        guard phase == .focus else { return }
        cancelTimer()
        notifications.cancelAll()
        completeActiveTaskIfAny()
        closeCurrentWave(reason: .endedEarlyComplete, completedTask: true)
        advanceAfterFocus()
    }

    func markElapsedWaveComplete() {
        guard phase == .awaitingEndDecision else { return }
        completeActiveTaskIfAny()
        closeCurrentWave(reason: .elapsedComplete, completedTask: true)
        advanceAfterFocus()
    }

    func markElapsedWaveCarryOver() {
        guard phase == .awaitingEndDecision else { return }
        if let task = activeTask {
            task.carryOverCount += 1
        }
        closeCurrentWave(reason: .elapsedCarryOver, completedTask: false)
        advanceAfterFocus()
    }

    func cancel() {
        cancelTimer()
        notifications.cancelAll()
        if let wave = currentWave, wave.endedAt == nil {
            closeCurrentWave(reason: .cancelled, completedTask: false)
        }
        phase = .idle
        endDate = nil
        pausedRemaining = nil
        activeTask = nil
        currentWave = nil
        completedFocusWavesInCycle = 0
    }

    func startBreakIfPending() {
        // Used when autoStartBreak is off and user manually triggers the break
        guard phase == .shortBreak || phase == .longBreak, endDate == nil else { return }
        let duration = TimeInterval(
            phase == .longBreak ? settings.longBreakMinutes : settings.shortBreakMinutes
        ) * 60
        let end = Date().addingTimeInterval(duration)
        endDate = end
        pausedRemaining = nil
        scheduleElapsedDispatch()
        if settings.notificationsEnabled {
            notifications.scheduleBreakEnd(fireAt: end)
        }
    }

    // MARK: - Internals

    private func completeActiveTaskIfAny() {
        guard let task = activeTask else { return }
        task.setComplete(true)
        if task.recurrence != nil, let next = task.nextRecurrenceDueDate() {
            // Recurring parents spawn a fresh occurrence with no children — user's choice per spec.
            let clone = TaskItem(
                title: task.title,
                notes: task.notes,
                priority: task.priority,
                dueDate: next,
                recurrence: task.recurrence
            )
            modelContext.insert(clone)
        }
        try? modelContext.save()
    }

    private func closeCurrentWave(reason: Wave.EndReason, completedTask: Bool) {
        guard let wave = currentWave else { return }
        wave.endedAt = .now
        wave.endReasonValue = reason.rawValue
        wave.completedTaskAtEnd = completedTask
        try? modelContext.save()
    }

    private func advanceAfterFocus() {
        completedFocusWavesInCycle += 1
        activeTask = nil
        currentWave = nil
        enterBreak()
    }

    private func enterBreak() {
        let isLong = completedFocusWavesInCycle >= max(1, settings.wavesUntilLongBreak)
        if isLong { completedFocusWavesInCycle = 0 }
        phase = isLong ? .longBreak : .shortBreak

        if settings.autoStartBreak {
            let duration = TimeInterval(
                isLong ? settings.longBreakMinutes : settings.shortBreakMinutes
            ) * 60
            let end = Date().addingTimeInterval(duration)
            endDate = end
            pausedRemaining = nil
            scheduleElapsedDispatch()
            if settings.notificationsEnabled {
                notifications.scheduleBreakEnd(fireAt: end)
            }
        } else {
            endDate = nil
            pausedRemaining = nil
        }
    }

    private func scheduleElapsedDispatch() {
        elapsedTask?.cancel()
        guard let endDate else { return }
        let delay = max(0, endDate.timeIntervalSinceNow)
        elapsedTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            if Task.isCancelled { return }
            await MainActor.run { self?.handlePhaseElapsed() }
        }
    }

    private func cancelTimer() {
        elapsedTask?.cancel()
        elapsedTask = nil
    }

    private func handlePhaseElapsed() {
        switch phase {
        case .focus:
            phase = .awaitingEndDecision
            endDate = nil
        case .shortBreak, .longBreak:
            if settings.autoStartNextWave {
                startFocus(with: nil)
            } else {
                phase = .idle
                endDate = nil
                pausedRemaining = nil
            }
        default:
            break
        }
    }
}
