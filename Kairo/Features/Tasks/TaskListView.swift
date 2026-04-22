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
        HStack(spacing: 8) {
            if task.hasChildren {
                Button {
                    withAnimation(.smooth) {
                        toggleExpanded(task.persistentModelID)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expandedIDs.contains(task.persistentModelID) ? 90 : 0))
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
            } else {
                Spacer().frame(width: 16)
            }

            TaskRowView(
                task: task,
                isActive: engine.activeTask?.persistentModelID == task.persistentModelID,
                onToggleComplete: { toggle(task) },
                onMakeActive: { engine.activeTask = task }
            )

            if task.hasChildren {
                progressBadge(done: task.completedChildCount, total: task.children.count)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { editingTask = task }
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

    private func toggleExpanded(_ id: PersistentIdentifier) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }

    private func toggle(_ task: TaskItem) {
        let willBeComplete = !task.isComplete
        task.setComplete(willBeComplete)
        if willBeComplete {
            // Clear active-task reference if it or any of its children were active.
            let completedIDs = Set([task.persistentModelID] + task.children.map(\.persistentModelID))
            if let activeID = engine.activeTask?.persistentModelID, completedIDs.contains(activeID) {
                engine.activeTask = nil
            }
        }
        try? context.save()
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
