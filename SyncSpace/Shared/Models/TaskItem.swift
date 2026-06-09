//
//  TaskItem.swift
//  SyncSpace
//
//  A focus task. Persisted by SwiftData on the Mac via `TaskRecord`
//  and wire-transported as a value type via `TaskItem`.
//

import Foundation
import SwiftData

public struct TaskItem: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    public var isCompleted: Bool
    public var createdAt: Date
    public var completedAt: Date?
    public var sortIndex: Int

    public init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        createdAt: Date = .now,
        completedAt: Date? = nil,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.sortIndex = sortIndex
    }
}

@Model
public final class TaskRecord {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var isCompleted: Bool
    public var createdAt: Date
    public var completedAt: Date?
    public var sortIndex: Int

    public init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        createdAt: Date = .now,
        completedAt: Date? = nil,
        sortIndex: Int = 0
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.sortIndex = sortIndex
    }

    public var snapshot: TaskItem {
        TaskItem(
            id: id,
            title: title,
            isCompleted: isCompleted,
            createdAt: createdAt,
            completedAt: completedAt,
            sortIndex: sortIndex
        )
    }

    public func apply(_ item: TaskItem) {
        title = item.title
        isCompleted = item.isCompleted
        createdAt = item.createdAt
        completedAt = item.completedAt
        sortIndex = item.sortIndex
    }
}
