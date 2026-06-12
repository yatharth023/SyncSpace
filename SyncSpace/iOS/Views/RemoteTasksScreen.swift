//
//  RemoteTasksScreen.swift
//  SyncSpace
//

#if os(iOS)
import SwiftUI

struct RemoteTasksScreen: View {
    @Bindable var model: AppModel
    @State private var newTitle: String = ""
    @FocusState private var composerFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.md) {
                ScreenHeader(
                    title: "Tasks",
                    subtitle: "\(model.tasks.filter { !$0.isCompleted }.count) open · \(model.tasks.filter { $0.isCompleted }.count) done",
                    trailing: AnyView(
                        ConnectionBadge(
                            status: model.peerManager.status,
                            peerNames: model.peerManager.connectedPeerNames,
                            compact: true
                        )
                    )
                )

                composer

                LazyVStack(spacing: DS.Spacing.sm) {
                    if model.tasks.isEmpty {
                        emptyState
                    } else {
                        ForEach(model.tasks.sorted { $0.sortIndex < $1.sortIndex }) { task in
                            TaskCard(
                                task: task,
                                onToggle: {
                                    HapticManager.shared.trigger(.selection)
                                    model.toggleTask(task.id)
                                },
                                onDelete: {
                                    HapticManager.shared.trigger(.warning)
                                    model.deleteTask(id: task.id)
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .scrollIndicators(.hidden)
        // Drag-down on the task list resigns the field — mirrors Reminders,
        // Notes, Mail. Without this the keyboard stays up once the field
        // takes focus and the user scrolls.
        .scrollDismissesKeyboard(.interactively)
        // Tap any non-interactive space on the screen to resign first
        // responder. `simultaneousGesture` (not `onTapGesture`) so it does
        // not eat taps on the rows or the composer button.
        .simultaneousGesture(
            TapGesture().onEnded { composerFocused = false }
        )
        // Always-present Done above the keyboard so the user can dismiss
        // even when the list cannot be scrolled.
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { composerFocused = false }
            }
        }
    }

    private var composer: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "plus.circle.fill").foregroundStyle(AppTheme.accent)
            TextField("Add a focus task…", text: $newTitle)
                .focused($composerFocused)
                .submitLabel(.done)
                .onSubmit(commit)
            if !newTitle.isEmpty {
                Button("Add", action: commit)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
            }
        }
        .padding(DS.Spacing.md)
        .glassCard(cornerRadius: DS.Radius.md)
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.xs) {
            Image(systemName: "sparkles")
                .font(.system(size: 30))
                .foregroundStyle(AppTheme.accent)
            Text("No tasks yet").font(.headline)
            Text("Add tasks here or on the Mac. They sync instantly.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private func commit() {
        model.addTask(title: newTitle)
        newTitle = ""
        // Resign the field on submit. The previous version re-focused the
        // composer here, which is exactly what trapped the keyboard on iOS:
        // tapping Done / Return immediately handed focus back to the field
        // and the keyboard never collapsed.
        composerFocused = false
    }
}

private struct TaskCard: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(task.isCompleted ? AppTheme.mint : Color.primary.opacity(0.30), lineWidth: 1.6)
                        .frame(width: 26, height: 26)
                    if task.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.mint)
                    }
                }
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .strikethrough(task.isCompleted, color: .secondary)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                Text(task.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(DS.Spacing.md)
        .glassCard(cornerRadius: DS.Radius.md)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
#endif
