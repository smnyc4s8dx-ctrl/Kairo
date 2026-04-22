import SwiftUI
import SwiftData

struct TimerView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(AppSettings.self) private var settings
    @Environment(AmbientSoundService.self) private var sounds

    let compact: Bool

    init(compact: Bool = false) {
        self.compact = compact
    }

    var body: some View {
        VStack(spacing: compact ? 16 : 24) {
            TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                timerDial
            }

            activeTaskChip

            controls
        }
        .padding(compact ? 16 : 24)
        .animation(.smooth, value: engine.phase)
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
                    .contentTransition(.numericText(countsDown: true))

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
            Button {
                engine.startFocus(with: engine.activeTask)
            } label: {
                controlLabel("Start Wave", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .focus:
            HStack(spacing: 12) {
                secondaryButton("Skip", systemImage: "forward.end.fill") {
                    engine.skip()
                }
                primaryButton(
                    engine.isPaused ? "Resume" : "Pause",
                    systemImage: engine.isPaused ? "play.fill" : "pause.fill"
                ) {
                    engine.isPaused ? engine.resume() : engine.pause()
                }
                secondaryButton("Done Early", systemImage: "checkmark.circle.fill") {
                    engine.endFocusEarlyComplete()
                }
                .disabled(engine.activeTask == nil)
            }

        case .awaitingEndDecision:
            HStack(spacing: 12) {
                Button(role: .none) {
                    engine.markElapsedWaveCarryOver()
                } label: {
                    controlLabel("Carry Over", systemImage: "arrow.uturn.forward")
                }
                .buttonStyle(.bordered)
                .disabled(engine.activeTask == nil)

                Button {
                    engine.markElapsedWaveComplete()
                } label: {
                    controlLabel("Mark Complete", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }

        case .shortBreak, .longBreak:
            HStack(spacing: 12) {
                if engine.endDate == nil {
                    Button {
                        engine.startBreakIfPending()
                    } label: {
                        controlLabel("Start Break", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    secondaryButton(
                        engine.isPaused ? "Resume" : "Pause",
                        systemImage: engine.isPaused ? "play.fill" : "pause.fill"
                    ) {
                        engine.isPaused ? engine.resume() : engine.pause()
                    }
                    secondaryButton("Skip Break", systemImage: "forward.end.fill") {
                        engine.skip()
                    }
                }
            }
        }
    }

    private func controlLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.titleAndIcon)
            .frame(minWidth: 110)
    }

    private func primaryButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { controlLabel(title, systemImage: systemImage) }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
    }

    private func secondaryButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { controlLabel(title, systemImage: systemImage) }
            .buttonStyle(.bordered)
            .controlSize(.large)
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
