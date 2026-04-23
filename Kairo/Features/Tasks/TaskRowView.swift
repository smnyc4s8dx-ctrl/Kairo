import SwiftUI

struct TaskRowView: View {
    @Bindable var task: TaskItem
    var isActive: Bool
    var onToggleComplete: () -> Void
    var onMakeActive: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onToggleComplete) {
                Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isComplete ? Color.accentColor : Color.secondary)
                    .symbolEffect(.bounce, value: task.isComplete)
            }
            .buttonStyle(.plain)
            .help(task.isComplete ? "Mark as incomplete" : "Mark complete")

            Text(task.title)
                .font(.body)
                .strikethrough(task.isComplete)
                .foregroundStyle(task.isComplete ? .secondary : .primary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isActive {
                Image(systemName: "target")
                    .font(.callout)
                    .foregroundStyle(Color.accentColor)
                    .padding(6)
                    .background(Color.accentColor.opacity(0.15), in: Circle())
                    .help("Active focus task")
            } else if !task.isComplete {
                Button(action: onMakeActive) {
                    Image(systemName: "target")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(6)
                        .background(.thinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .help("Focus on this task")
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
