import SwiftUI
import SwiftData

struct AddEditTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private let existing: TaskItem?

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var priority: TaskItem.Priority = .none
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = .now
    @State private var hasRecurrence: Bool = false
    @State private var recurrence: TaskItem.Recurrence = .daily

    @State private var subtasks: [SubtaskDraft] = []

    @State private var showNotes: Bool = false
    @State private var showCustomDate: Bool = false
    #if os(iOS)
    @State private var subtasksEditMode: EditMode = .inactive
    #endif

    @FocusState private var titleFocused: Bool
    @FocusState private var subtaskFocus: SubtaskDraft.ID?

    init(task: TaskItem? = nil) {
        self.existing = task
    }

    /// Subtasks UI is hidden when editing a child task (no grandchildren per our one-level rule).
    private var canHaveSubtasks: Bool {
        existing?.parent == nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                middleArea

                if canHaveSubtasks {
                    addSubtaskBar
                }

                composerBar
            }
            .navigationTitle(existing == nil ? "New Task" : "Edit Task")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbarContent }
            .onAppear { hydrate() }
            .task {
                guard existing == nil else { return }
                try? await Task.sleep(for: .milliseconds(120))
                titleFocused = true
            }
            .sheet(isPresented: $showCustomDate) { customDatePicker }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Middle area (notes + subtasks)

    private var middleArea: some View {
        VStack(spacing: 0) {
            if showNotes {
                notesField
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if canHaveSubtasks && !subtasks.isEmpty {
                subtasksList
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Notes", systemImage: "note.text")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    withAnimation(.smooth) { showNotes = false }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            TextField("Add a note…", text: $notes, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...8)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.12))
                )
        }
    }

    private var subtasksList: some View {
        List {
            ForEach($subtasks) { $draft in
                SubtaskDraftRow(
                    draft: $draft,
                    focus: $subtaskFocus,
                    onSubmit: { appendDraftIfNeeded(after: draft.id) }
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            .onMove { from, to in
                subtasks.move(fromOffsets: from, toOffset: to)
            }
            .onDelete { offsets in
                subtasks.remove(atOffsets: offsets)
            }
        }
        #if os(iOS)
        .listStyle(.plain)
        .environment(\.editMode, $subtasksEditMode)
        #endif
        .scrollContentBackground(.hidden)
    }

    // MARK: - Add subtask button (above chips)

    private var addSubtaskBar: some View {
        HStack(spacing: 12) {
            Button {
                addEmptySubtask()
            } label: {
                Label("Add subtask", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)

            Spacer()

            #if os(iOS)
            if subtasks.count >= 2 {
                Button {
                    withAnimation {
                        subtasksEditMode = subtasksEditMode == .active ? .inactive : .active
                    }
                } label: {
                    Text(subtasksEditMode == .active ? "Done" : "Reorder")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            #endif
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Composer (chips + title + send)

    private var composerBar: some View {
        VStack(spacing: 10) {
            chipRow
                .padding(.horizontal, 16)
                .padding(.top, 10)

            titleRow
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
        }
        .background(.bar)
        .overlay(alignment: .top) {
            Divider().opacity(0.6)
        }
    }

    private var chipRow: some View {
        #if os(macOS)
        // Plain HStack on macOS — wrapping in a horizontal ScrollView lets trackpad
        // left/right gestures dismiss the sheet. The sheet is sized wide enough to
        // fit all four chips once the Menu dropdown chevrons are hidden.
        HStack(spacing: 8) {
            priorityChip
            dueDateChip
            recurrenceChip
            notesChip
        }
        #else
        // Horizontal scroll on iPhone — active chip labels ("Every Friday", date)
        // can exceed the iPhone content width; scroll preserves full visibility.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                priorityChip
                dueDateChip
                recurrenceChip
                notesChip
            }
        }
        #endif
    }

    private var titleRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("What needs doing?", text: $title, axis: .vertical)
                .font(.body)
                .textFieldStyle(.plain)
                .focused($titleFocused)
                .submitLabel(.done)
                .onSubmit { if canSave { save() } }
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.gray.opacity(0.14))
                )

            sendButton
        }
    }

    private var sendButton: some View {
        Button {
            save()
        } label: {
            Image(systemName: "arrow.up")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(canSave ? Color.accentColor : Color.gray.opacity(0.35))
                )
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .animation(.smooth(duration: 0.2), value: canSave)
    }

    // MARK: - Chips

    private var priorityChip: some View {
        Menu {
            ForEach(TaskItem.Priority.allCases) { p in
                Button {
                    withAnimation(.smooth) { priority = p }
                } label: {
                    Label(p.label, systemImage: p.symbol)
                }
            }
        } label: {
            chipLabel(
                systemImage: priority == .none ? "flag" : priority.symbol,
                text: priority == .none ? "Priority" : priority.label,
                tint: priorityColor,
                isActive: priority != .none
            )
        }
        .menuIndicator(.hidden)
    }

    private var dueDateChip: some View {
        Menu {
            Button {
                setDue(Calendar.current.startOfDay(for: .now))
            } label: { Label("Today", systemImage: "sun.max") }

            Button {
                if let d = Calendar.current.date(byAdding: .day, value: 1, to: .now) {
                    setDue(Calendar.current.startOfDay(for: d))
                }
            } label: { Label("Tomorrow", systemImage: "sunrise") }

            Button {
                if let d = Calendar.current.date(byAdding: .day, value: 7, to: .now) {
                    setDue(Calendar.current.startOfDay(for: d))
                }
            } label: { Label("Next week", systemImage: "calendar") }

            Divider()

            Button {
                showCustomDate = true
            } label: { Label("Pick a date…", systemImage: "calendar.badge.clock") }

            if hasDueDate {
                Divider()
                Button(role: .destructive) {
                    withAnimation { hasDueDate = false }
                } label: { Label("Remove", systemImage: "xmark") }
            }
        } label: {
            chipLabel(
                systemImage: "calendar",
                text: hasDueDate
                    ? dueDate.formatted(.dateTime.month(.abbreviated).day())
                    : "Due",
                tint: .orange,
                isActive: hasDueDate
            )
        }
        .menuIndicator(.hidden)
    }

    private var recurrenceChip: some View {
        Menu {
            ForEach(TaskItem.Recurrence.allCases) { r in
                Button {
                    withAnimation {
                        recurrence = r
                        hasRecurrence = true
                    }
                } label: { Text(r.label) }
            }
            if hasRecurrence {
                Divider()
                Button(role: .destructive) {
                    withAnimation { hasRecurrence = false }
                } label: { Label("No repeat", systemImage: "xmark") }
            }
        } label: {
            chipLabel(
                systemImage: "repeat",
                text: hasRecurrence
                    ? recurrence.contextualLabel(dueDate: hasDueDate ? dueDate : nil)
                    : "Repeat",
                tint: .purple,
                isActive: hasRecurrence
            )
        }
        .menuIndicator(.hidden)
    }

    private var notesChip: some View {
        Button {
            withAnimation(.smooth) { showNotes.toggle() }
        } label: {
            chipLabel(
                systemImage: "note.text",
                text: notes.isEmpty ? "Notes" : "Notes · \(notes.count)",
                tint: .gray,
                isActive: !notes.isEmpty || showNotes
            )
        }
    }

    private func chipLabel(systemImage: String, text: String, tint: Color, isActive: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .imageScale(.small)
            Text(text)
                .lineLimit(1)
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(isActive ? tint.opacity(0.18) : Color.gray.opacity(0.14))
        )
        .overlay(
            Capsule().strokeBorder(
                isActive ? tint.opacity(0.3) : Color.clear,
                lineWidth: 0.75
            )
        )
        .foregroundStyle(isActive ? tint : .primary)
        .contentTransition(.opacity)
    }

    private var priorityColor: Color {
        switch priority {
        case .none: .gray
        case .low: .blue
        case .medium: .orange
        case .high: .red
        }
    }

    // MARK: - Custom date sheet

    private var customDatePicker: some View {
        NavigationStack {
            DatePicker(
                "Due date",
                selection: $dueDate,
                in: Date.now...,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Due date")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCustomDate = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Set") {
                        hasDueDate = true
                        showCustomDate = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        #if os(macOS)
        ToolbarItem(placement: .confirmationAction) {
            Button(existing == nil ? "Save" : "Save Changes") { save() }
                .disabled(!canSave)
        }
        #endif
    }

    // MARK: - Subtask actions

    private func addEmptySubtask() {
        let draft = SubtaskDraft()
        subtasks.append(draft)
        subtaskFocus = draft.id
    }

    private func appendDraftIfNeeded(after id: SubtaskDraft.ID) {
        guard let idx = subtasks.firstIndex(where: { $0.id == id }) else { return }
        guard !subtasks[idx].title.trimmingCharacters(in: .whitespaces).isEmpty else {
            subtaskFocus = nil
            return
        }
        let next = SubtaskDraft()
        subtasks.insert(next, at: idx + 1)
        subtaskFocus = next.id
    }

    // MARK: - Save

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func setDue(_ date: Date) {
        withAnimation {
            hasDueDate = true
            dueDate = date
        }
    }

    private func hydrate() {
        guard let t = existing else { return }
        title = t.title
        notes = t.notes
        priority = t.priority
        if let due = t.dueDate { hasDueDate = true; dueDate = due }
        if let rec = t.recurrence { hasRecurrence = true; recurrence = rec }
        if !notes.isEmpty { showNotes = true }
        subtasks = t.sortedChildren.map { SubtaskDraft(title: $0.title, existingID: $0.persistentModelID) }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let parent: TaskItem
        if let existing {
            existing.title = trimmed
            existing.notes = notes
            existing.priority = priority
            existing.dueDate = hasDueDate ? dueDate : nil
            existing.recurrence = hasRecurrence ? recurrence : nil
            parent = existing
        } else {
            parent = TaskItem(
                title: trimmed,
                notes: notes,
                priority: priority,
                dueDate: hasDueDate ? dueDate : nil,
                recurrence: hasRecurrence ? recurrence : nil
            )
            context.insert(parent)
        }

        if canHaveSubtasks {
            reconcileSubtasks(parent: parent)
        }

        try? context.save()
        dismiss()
    }

    private func reconcileSubtasks(parent: TaskItem) {
        // Diff existing children against draft list.
        let nonEmpty = subtasks.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
        let draftExistingIDs = Set(nonEmpty.compactMap(\.existingID))

        // 1. Delete children no longer present in drafts.
        for child in parent.children where !draftExistingIDs.contains(child.persistentModelID) {
            context.delete(child)
        }

        // 2. Update kept children + insert new ones, with sortOrder matching draft list position.
        for (index, draft) in nonEmpty.enumerated() {
            let trimmedTitle = draft.title.trimmingCharacters(in: .whitespaces)
            if let id = draft.existingID,
               let child = parent.children.first(where: { $0.persistentModelID == id }) {
                child.title = trimmedTitle
                child.sortOrder = index
            } else {
                let child = TaskItem(title: trimmedTitle, parent: parent, sortOrder: index)
                context.insert(child)
            }
        }
    }
}

// MARK: - Subtask draft model + row

struct SubtaskDraft: Identifiable, Hashable {
    let id: UUID
    var title: String
    var existingID: PersistentIdentifier?

    init(title: String = "", existingID: PersistentIdentifier? = nil) {
        self.id = UUID()
        self.title = title
        self.existingID = existingID
    }
}

private struct SubtaskDraftRow: View {
    @Binding var draft: SubtaskDraft
    var focus: FocusState<SubtaskDraft.ID?>.Binding
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle")
                .font(.body)
                .foregroundStyle(.secondary)

            TextField("Subtask", text: $draft.title)
                .textFieldStyle(.plain)
                .focused(focus, equals: draft.id)
                .submitLabel(.next)
                .onSubmit(onSubmit)
        }
    }
}
