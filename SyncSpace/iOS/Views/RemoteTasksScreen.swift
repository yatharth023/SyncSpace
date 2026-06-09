//
//  RemoteTasksScreen.swift
//  SyncSpace
//
//  Tasks tab for iPhone. Adds, toggles, deletes all reflect on the Mac
//  immediately.
//

#if os(iOS)
import SwiftUI

struct RemoteTasksScreen: View {
    @Bindable var model: AppModel
    @State private var newTitle: String = ""
    @FocusState private var composerFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                composer

                VStack(spacing: 10) {
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
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 48)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tasks").font(.title.weight(.bold))
                Text("\(model.tasks.filter { !$0.isCompleted }.count) open · \(model.tasks.filter { $0.isCompleted }.count) done")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ConnectionBadge(
                status: model.peerManager.status,
                peerNames: model.peerManager.connectedPeerNames,
                compact: true
            )
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(AppTheme.accent)
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
        .padding(14)
        .glassCard(cornerRadius: 18)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 30))
                .foregroundStyle(AppTheme.accent)
            Text("No tasks yet")
                .font(.headline)
            Text("Add tasks here or on the Mac. They sync instantly.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private func commit() {
        model.addTask(title: newTitle)
        newTitle = ""
        composerFocused = true
    }
}

private struct TaskCard: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .stroke(task.isCompleted ? AppTheme.mint : .white.opacity(0.3), lineWidth: 1.6)
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
        .padding(16)
        .glassCard(cornerRadius: 18)
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
