//
//  TasksScreen.swift
//  SyncSpace
//

#if os(macOS)
import SwiftUI

struct TasksScreen: View {
    @Bindable var model: AppModel
    @State private var newTitle: String = ""
    @State private var filter: TaskFilter = .all
    @FocusState private var composerFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                ScreenHeader(
                    title: "Tasks",
                    subtitle: "Plan and check off the work you'll do during your next session.",
                    trailing: AnyView(
                        Text("\(openCount) open · \(doneCount) done")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    )
                )

                composer
                filterBar

                LazyVStack(spacing: DS.Spacing.sm) {
                    ForEach(filteredTasks) { task in
                        TaskRow(
                            task: task,
                            onToggle: { model.toggleTask(task.id) },
                            onDelete: { model.deleteTask(id: task.id) },
                            onRename: { newTitle in
                                var copy = task
                                copy.title = newTitle
                                model.updateTask(copy)
                            }
                        )
                    }
                    if filteredTasks.isEmpty { emptyState }
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xxl)
            .frame(maxWidth: 880)
            .frame(maxWidth: .infinity)
        }
    }

    private var openCount: Int { model.tasks.filter { !$0.isCompleted }.count }
    private var doneCount: Int { model.tasks.filter { $0.isCompleted }.count }

    private var filteredTasks: [TaskItem] {
        switch filter {
        case .all:       return model.tasks.sorted { $0.sortIndex < $1.sortIndex }
        case .open:      return model.tasks.filter { !$0.isCompleted }.sorted { $0.sortIndex < $1.sortIndex }
        case .completed: return model.tasks.filter { $0.isCompleted }.sorted {
            ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
        }
        }
    }

    private var composer: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
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
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .glassCard()
    }

    private var filterBar: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(TaskFilter.allCases) { option in
                Button {
                    withAnimation(DS.Motion.calm) { filter = option }
                } label: {
                    Text(option.title)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs + 1)
                        .background(
                            Capsule().fill(filter == option ? AppTheme.accent.opacity(0.22) : Color.primary.opacity(0.05))
                        )
                        .overlay(
                            Capsule().strokeBorder(filter == option ? AppTheme.accent : Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 32))
                .foregroundStyle(AppTheme.accent)
            Text("Nothing here yet").font(.headline)
            Text("Add a task above to get started. They'll appear instantly on your iPhone.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 360)
        .padding(DS.Spacing.xl)
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
        HStack(spacing: DS.Spacing.sm) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(task.isCompleted ? AppTheme.mint : Color.primary.opacity(0.30), lineWidth: 1.6)
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
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md - 2)
        .glassCard(cornerRadius: DS.Radius.md)
        .onHover { hovering = $0 }
    }

    private func beginRename() {
        draftTitle = task.title
        editing = true
        renameFocused = true
    }

    private func commitRename() {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, trimmed != task.title { onRename(trimmed) }
        editing = false
    }
}
#endif
