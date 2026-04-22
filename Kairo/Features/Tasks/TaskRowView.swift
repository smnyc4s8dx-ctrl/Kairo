import SwiftUI

struct TaskRowView: View {
    @Bindable var task: TaskItem
    var isActive: Bool
    var onToggleComplete: () -> Void
    var onMakeActive: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggleComplete) {
                Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isComplete ? Color.accentColor : Color.secondary)
                    .symbolEffect(.bounce, value: task.isComplete)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isComplete)
                    .foregroundStyle(task.isComplete ? .secondary : .primary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if task.priority != .none {
                        Label(task.priority.label, systemImage: task.priority.symbol)
                            .labelStyle(.titleAndIcon)
                            .font(.caption2)
                            .foregroundStyle(priorityColor)
                    }
                    if let due = task.dueDate {
                        Label {
                            Text(due, format: .dateTime.month(.abbreviated).day())
                        } icon: {
                            Image(systemName: "calendar")
                        }
                        .font(.caption2)
                        .foregroundStyle(isOverdue ? .red : .secondary)
                    }
                    if let recur = task.recurrence {
                        Label(recur.contextualLabel(dueDate: task.dueDate), systemImage: "repeat")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if task.carryOverCount > 0 {
                        Label("\(task.carryOverCount)", systemImage: "arrow.uturn.forward")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer(minLength: 4)

            if isActive {
                Image(systemName: "target")
                    .font(.callout)
                    .foregroundStyle(Color.accentColor)
                    .padding(6)
                    .background(Color.accentColor.opacity(0.15), in: Circle())
            } else if !task.isComplete {
                Button(action: onMakeActive) {
                    Image(systemName: "target")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(.thinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private var priorityColor: Color {
        switch task.priority {
        case .none: .secondary
        case .low: .blue
        case .medium: .orange
        case .high: .red
        }
    }

    private var isOverdue: Bool {
        guard let due = task.dueDate, !task.isComplete else { return false }
        return due < Calendar.current.startOfDay(for: .now)
    }
}
