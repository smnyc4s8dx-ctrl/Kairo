import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(\.modelContext) private var context
    @Environment(TimerEngine.self) private var engine

    @Query(
        filter: #Predicate<TaskItem> { !$0.isComplete && $0.parent == nil },
        sort: \TaskItem.createdAt,
        order: .reverse
    )
    private var openTasks: [TaskItem]

    @State private var editingTask: TaskItem?
    @State private var expandedIDs: Set<PersistentIdentifier> = []

    var body: some View {
        List {
            if openTasks.isEmpty {
                ContentUnavailableView(
                    "No tasks",
                    systemImage: "checklist",
                    description: Text("Use the + button below to add your first task.")
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(openTasks) { task in
                    parentRow(task)

                    if expandedIDs.contains(task.persistentModelID) {
                        expandedDetails(for: task)

                        ForEach(task.sortedChildren) { child in
                            childRow(child, under: task)
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .sheet(item: $editingTask) { task in
            AddEditTaskSheet(task: task)
        }
    }

    @ViewBuilder
    private func parentRow(_ task: TaskItem) -> some View {
        HStack(alignment: .center, spacing: 8) {
            TaskRowView(
                task: task,
                isActive: engine.activeTask?.persistentModelID == task.persistentModelID,
                onToggleComplete: { toggle(task) },
                onMakeActive: { engine.activeTask = task }
            )

            if task.hasChildren {
                progressBadge(done: task.completedChildCount, total: task.children.count)
            }

            if hasExpandable(task) {
                Button {
                    withAnimation(.smooth) {
                        toggleExpanded(task.persistentModelID)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expandedIDs.contains(task.persistentModelID) ? 90 : 0))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { openEditor(for: task) }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { delete(task) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button { engine.activeTask = task } label: {
                Label("Focus", systemImage: "target")
            }
            .tint(.accentColor)
        }
        .contextMenu {
            Button {
                editingTask = task
            } label: {
                Label("Edit & Subtasks", systemImage: "list.bullet.indent")
            }
            Button(role: .destructive) {
                delete(task)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func childRow(_ child: TaskItem, under parent: TaskItem) -> some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 2)
                .padding(.leading, 20)
                .padding(.trailing, 10)

            TaskRowView(
                task: child,
                isActive: engine.activeTask?.persistentModelID == child.persistentModelID,
                onToggleComplete: { toggle(child) },
                onMakeActive: { engine.activeTask = child }
            )
        }
        .contentShape(Rectangle())
        .onTapGesture { editingTask = child }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { delete(child) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button { engine.activeTask = child } label: {
                Label("Focus", systemImage: "target")
            }
            .tint(.accentColor)
        }
    }

    private func progressBadge(done: Int, total: Int) -> some View {
        Text("\(done)/\(total)")
            .font(.caption2.monospacedDigit().weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(done == total ? Color.green.opacity(0.2) : Color.gray.opacity(0.15))
            )
            .foregroundStyle(done == total ? .green : .secondary)
    }

    @ViewBuilder
    private func expandedDetails(for task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !task.notes.isEmpty {
                Text(task.notes)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if hasMetadata(task) {
                metadataBadges(for: task)
            }
        }
        .padding(.leading, 32)
        .padding(.vertical, 4)
    }

    private func metadataBadges(for task: TaskItem) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if task.priority != .none {
                    metaBadge(
                        text: task.priority.label,
                        system: task.priority.symbol,
                        tint: priorityColor(task.priority)
                    )
                }
                if let due = task.dueDate {
                    metaBadge(
                        text: due.formatted(.dateTime.month(.abbreviated).day()),
                        system: "calendar",
                        tint: isOverdue(due, task: task) ? .red : .orange
                    )
                }
                if let recur = task.recurrence {
                    metaBadge(
                        text: recur.contextualLabel(dueDate: task.dueDate),
                        system: "repeat",
                        tint: .purple
                    )
                }
                if task.carryOverCount > 0 {
                    metaBadge(
                        text: "\(task.carryOverCount)×",
                        system: "arrow.uturn.forward",
                        tint: .orange
                    )
                }
            }
        }
    }

    private func metaBadge(text: String, system: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: system).font(.caption2)
            Text(text).font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.15)))
        .foregroundStyle(tint)
    }

    private func priorityColor(_ priority: TaskItem.Priority) -> Color {
        switch priority {
        case .none: .gray
        case .low: .blue
        case .medium: .orange
        case .high: .red
        }
    }

    private func isOverdue(_ due: Date, task: TaskItem) -> Bool {
        !task.isComplete && due < Calendar.current.startOfDay(for: .now)
    }

    private func hasMetadata(_ task: TaskItem) -> Bool {
        task.priority != .none
            || task.dueDate != nil
            || task.recurrence != nil
            || task.carryOverCount > 0
    }

    private func hasExpandable(_ task: TaskItem) -> Bool {
        task.hasChildren || !task.notes.isEmpty || hasMetadata(task)
    }

    private func toggleExpanded(_ id: PersistentIdentifier) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }

    private func openEditor(for task: TaskItem) {
        editingTask = task
    }

    private func toggle(_ task: TaskItem) {
        let willBeComplete = !task.isComplete
        let cascaded = task.setComplete(willBeComplete)
        if willBeComplete {
            let completedIDs = Set([task.persistentModelID] + cascaded)
            if let activeID = engine.activeTask?.persistentModelID, completedIDs.contains(activeID) {
                engine.activeTask = nil
            }
            try? context.save()
            task.postCompletionUndo(cascaded: cascaded, context: context)
        } else {
            try? context.save()
        }
    }

    private func delete(_ task: TaskItem) {
        if engine.activeTask?.persistentModelID == task.persistentModelID {
            engine.activeTask = nil
        }
        context.delete(task)
        try? context.save()
    }
}

struct CompletedTasksSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query(
        filter: #Predicate<TaskItem> { $0.isComplete },
        sort: \TaskItem.completedAt,
        order: .reverse
    )
    private var completed: [TaskItem]

    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            List {
                if completed.isEmpty {
                    ContentUnavailableView("No completed tasks", systemImage: "checkmark.circle")
                } else {
                    ForEach(completed) { task in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .strikethrough()
                                .foregroundStyle(.secondary)
                            if let at = task.completedAt {
                                Text(at, format: .relative(presentation: .named))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                context.delete(task)
                                try? context.save()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Completed")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if !completed.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button(role: .destructive) {
                            showClearConfirm = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                    }
                }
            }
            .confirmationDialog(
                "Delete all completed tasks?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete \(completed.count) \(completed.count == 1 ? "Task" : "Tasks")",
                       role: .destructive) {
                    clearAll()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    private func clearAll() {
        for task in completed {
            context.delete(task)
        }
        try? context.save()
        ToastCenter.shared.show("Cleared all completed tasks")
    }
}
