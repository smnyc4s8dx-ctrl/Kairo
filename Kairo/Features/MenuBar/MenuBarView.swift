#if os(macOS)
import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Environment(TimerEngine.self) private var engine
    @Environment(AppSettings.self) private var settings
    @Environment(\.openWindow) private var openWindow

    @State private var showSettings = false
    @State private var showAddTask = false

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            TimerView(compact: true)

            Divider()

            taskListSection

            Divider()

            footer
        }
        .frame(width: 380, height: 560)
        .background(.regularMaterial)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .frame(width: 420, height: 560)
        }
        .sheet(isPresented: $showAddTask) {
            AddEditTaskSheet()
                .frame(width: 420, height: 480)
        }
        .sheet(isPresented: Binding(
            get: { engine.phase == .awaitingEndDecision },
            set: { _ in }
        )) {
            WaveEndSheet()
                .frame(width: 380, height: 360)
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "timer")
                .foregroundStyle(Color.accentColor)
            Text("Kairo")
                .font(.headline)
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
    }

    private var taskListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.2)
                Spacer()
                Button {
                    showAddTask = true
                } label: {
                    Label("Add", systemImage: "plus")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            CompactTaskList()
                .frame(maxHeight: 200)
        }
    }

    private var footer: some View {
        HStack {
            Button(role: .destructive) {
                engine.cancel()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .disabled(engine.phase == .idle)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(12)
    }
}

private struct CompactTaskList: View {
    @Environment(\.modelContext) private var context
    @Environment(TimerEngine.self) private var engine

    @Query(
        filter: #Predicate<TaskItem> { !$0.isComplete && $0.parent == nil },
        sort: \TaskItem.createdAt,
        order: .reverse
    )
    private var tasks: [TaskItem]

    var body: some View {
        ScrollView {
            if tasks.isEmpty {
                Text("No open tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(tasks) { task in
                        TaskRowView(
                            task: task,
                            isActive: engine.activeTask?.persistentModelID == task.persistentModelID,
                            onToggleComplete: {
                                let willBeComplete = !task.isComplete
                                task.setComplete(willBeComplete)
                                if willBeComplete {
                                    let ids = Set([task.persistentModelID] + task.children.map(\.persistentModelID))
                                    if let activeID = engine.activeTask?.persistentModelID, ids.contains(activeID) {
                                        engine.activeTask = nil
                                    }
                                }
                                try? context.save()
                            },
                            onMakeActive: { engine.activeTask = task }
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            engine.activeTask?.persistentModelID == task.persistentModelID
                            ? Color.accentColor.opacity(0.08) : .clear
                        )
                    }
                }
            }
        }
    }
}

struct MenuBarLabel: View {
    @Environment(TimerEngine.self) private var engine

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            if engine.endDate != nil || engine.isPaused {
                Label(engine.remaining.mmss, systemImage: iconName)
                    .monospacedDigit()
            } else if engine.phase == .awaitingEndDecision {
                Image(systemName: "sparkles")
            } else {
                Image(systemName: "timer")
            }
        }
    }

    private var iconName: String {
        switch engine.phase {
        case .focus: "timer.circle.fill"
        case .shortBreak, .longBreak: "cup.and.saucer.fill"
        default: "timer"
        }
    }
}
#endif
