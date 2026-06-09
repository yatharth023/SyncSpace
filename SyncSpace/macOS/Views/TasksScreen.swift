//
//  TasksScreen.swift
//  SyncSpace
//
//  Mac tasks list with drag-and-drop reordering, swipe to complete, and
//  an inline composer along the top.
//

#if os(macOS)
import SwiftUI

struct TasksScreen: View {
    @Bindable var model: AppModel
    @State private var newTitle: String = ""
    @State private var filter: TaskFilter = .all
    @FocusState private var composerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filteredTasks) { task in
                        TaskRow(task: task,
                                onToggle: { model.toggleTask(task.id) },
                                onDelete: { model.deleteTask(id: task.id) },
                                onRename: { newTitle in
                                    var copy = task
                                    copy.title = newTitle
                                    model.updateTask(copy)
                                })
                    }
                    if filteredTasks.isEmpty {
                        emptyState
                    }
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 18)
            }
        }
    }

    private var filteredTasks: [TaskItem] {
        switch filter {
        case .all:       return model.tasks.sorted { $0.sortIndex < $1.sortIndex }
        case .open:      return model.tasks.filter { !$0.isCompleted }.sorted { $0.sortIndex < $1.sortIndex }
        case .completed: return model.tasks.filter { $0.isCompleted }.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(AppTheme.accent)
                TextField("Add a focus task…", text: $newTitle)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($composerFocused)
                    .onSubmit(addTask)

                if !newTitle.isEmpty {
                    Button("Add", action: addTask)
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                        .keyboardShortcut(.return, modifiers: [])
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .glassCard()

            HStack(spacing: 8) {
                ForEach(TaskFilter.allCases) { option in
                    Button {
                        withAnimation(.smooth(duration: 0.25)) {
                            filter = option
                        }
                    } label: {
                        Text(option.title)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(filter == option ? AppTheme.accent.opacity(0.3) : Color.white.opacity(0.05))
                            )
                            .overlay(
                                Capsule().stroke(filter == option ? AppTheme.accent : .white.opacity(0.12), lineWidth: 1)
                            )
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text("\(model.tasks.filter { !$0.isCompleted }.count) open · \(model.tasks.filter { $0.isCompleted }.count) done")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 36)
        .padding(.top, 24)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(AppTheme.accent)
            Text("Nothing here yet")
                .font(.headline)
            Text("Add a task above to get started. They'll appear instantly on your iPhone.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 360)
        .padding(40)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private func addTask() {
        model.addTask(title: newTitle)
        newTitle = ""
        composerFocused = true
    }
}

private enum TaskFilter: String, CaseIterable, Identifiable {
    case all, open, completed
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all:        return "All"
        case .open:       return "Open"
        case .completed:  return "Completed"
        }
    }
}

private struct TaskRow: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void

    @State private var hovering = false
    @State private var editing = false
    @State private var draftTitle: String = ""
    @FocusState private var renameFocused: Bool

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .stroke(task.isCompleted ? AppTheme.mint : Color.white.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if task.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.mint)
                    }
                }
            }
            .buttonStyle(.plain)

            if editing {
                TextField("", text: $draftTitle)
                    .textFieldStyle(.plain)
                    .focused($renameFocused)
                    .onSubmit { commitRename() }
                    .onExitCommand { editing = false }
            } else {
                Text(task.title)
                    .strikethrough(task.isCompleted, color: .secondary)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .onTapGesture(count: 2) { beginRename() }
            }

            Spacer()

            if let date = task.completedAt {
                Text(date, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if hovering, !editing {
                Button(action: beginRename) {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.borderless)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 14)
        .onHover { hovering = $0 }
    }

    private func beginRename() {
        draftTitle = task.title
        editing = true
        renameFocused = true
    }

    private func commitRename() {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, trimmed != task.title {
            onRename(trimmed)
        }
        editing = false
    }
}
#endif
