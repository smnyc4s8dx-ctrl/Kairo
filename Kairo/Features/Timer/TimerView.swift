import SwiftUI
import SwiftData

struct TimerView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(AppSettings.self) private var settings

    let compact: Bool

    init(compact: Bool = false) {
        self.compact = compact
    }

    var body: some View {
        VStack(spacing: compact ? 16 : 24) {
            dialTimeline

            activeTaskChip

            controls
        }
        .padding(compact ? 16 : 24)
    }

    /// Always wrap the dial in a `TimelineView`; inside, decide whether to
    /// actually consume ticks. Swapping the outer view structure on phase change
    /// can trigger a macOS AppKit layout recursion inside a MenuBarExtra popover.
    private var dialTimeline: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            timerDial
        }
    }

    private var timerDial: some View {
        ZStack {
            CircularProgressView(
                progress: engine.progress,
                lineWidth: compact ? 8 : 12,
                tint: phaseTint
            )

            VStack(spacing: 6) {
                Text(engine.remaining.mmss)
                    .font(.system(size: compact ? 44 : 72, weight: .light, design: .rounded))
                    .monospacedDigit()

                Text(phaseLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.2)
            }
        }
        .frame(
            width: compact ? 180 : 260,
            height: compact ? 180 : 260
        )
    }

    @ViewBuilder
    private var activeTaskChip: some View {
        if let task = engine.activeTask {
            VStack(spacing: 2) {
                if let parent = task.parent {
                    Text(parent.title)
                        .font(.caption2.italic())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    Image(systemName: "target")
                    Text(task.title)
                        .lineLimit(1)
                }
                .font(.callout.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: Capsule())
            .transition(.scale.combined(with: .opacity))
        } else if engine.phase == .focus || engine.phase == .awaitingEndDecision {
            Text("No active task")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch engine.phase {
        case .idle:
            primaryPill("Start Wave", systemImage: "play.fill") {
                engine.startFocus(with: engine.activeTask)
            }

        case .focus:
            HStack(spacing: 18) {
                iconCircle(systemImage: "forward.end.fill", label: "Skip") {
                    engine.skip()
                }

                primaryPill(
                    engine.isPaused ? "Resume" : "Pause",
                    systemImage: engine.isPaused ? "play.fill" : "pause.fill"
                ) {
                    engine.isPaused ? engine.resume() : engine.pause()
                }

                iconCircle(systemImage: "checkmark.circle.fill", label: "Done Early") {
                    engine.endFocusEarlyComplete()
                }
                .disabled(engine.activeTask == nil)
            }

        case .awaitingEndDecision:
            HStack(spacing: 12) {
                Button {
                    engine.markElapsedWaveCarryOver()
                } label: {
                    Label("Carry Over", systemImage: "arrow.uturn.forward")
                        .font(.subheadline.weight(.medium))
                        .frame(minWidth: 100)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(engine.activeTask == nil)
                .help("Keep this task for the next wave")

                Button {
                    engine.markElapsedWaveComplete()
                } label: {
                    Label("Mark Complete", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .help("Mark this task done and take a break")
            }

        case .shortBreak, .longBreak:
            if engine.endDate == nil {
                primaryPill("Start Break", systemImage: "play.fill") {
                    engine.startBreakIfPending()
                }
            } else {
                HStack(spacing: 18) {
                    iconCircle(systemImage: "forward.end.fill", label: "Skip Break") {
                        engine.skip()
                    }
                    primaryPill(
                        engine.isPaused ? "Resume" : "Pause",
                        systemImage: engine.isPaused ? "play.fill" : "pause.fill"
                    ) {
                        engine.isPaused ? engine.resume() : engine.pause()
                    }
                }
            }
        }
    }

    private func primaryPill(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 6) {
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 120)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .help(title)

            // Invisible caption preserves layout parity with iconCircle's visible caption.
            Text(title)
                .font(.caption2)
                .hidden()
        }
    }

    private func iconCircle(
        systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 6) {
            Button(action: action) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.medium))
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .accessibilityLabel(label)
            .help(label)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var phaseLabel: String {
        switch engine.phase {
        case .idle: "Ready"
        case .focus: engine.isPaused ? "Paused" : "Focus"
        case .awaitingEndDecision: "Wave complete"
        case .shortBreak: engine.isPaused ? "Break — paused" : "Short break"
        case .longBreak: engine.isPaused ? "Break — paused" : "Long break"
        }
    }

    private var phaseTint: Color {
        switch engine.phase {
        case .focus, .awaitingEndDecision: .accentColor
        case .shortBreak: .mint
        case .longBreak: .teal
        case .idle: .accentColor
        }
    }
}
