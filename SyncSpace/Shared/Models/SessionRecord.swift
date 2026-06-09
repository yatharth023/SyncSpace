//
//  SessionRecord.swift
//  SyncSpace
//
//  Persisted completion record. Drives streaks and charts on macOS.
//

import Foundation
import SwiftData

@Model
public final class SessionRecord {
    @Attribute(.unique) public var id: UUID
    public var sessionTypeID: String
    public var sessionTitle: String
    public var startedAt: Date
    public var completedAt: Date
    public var plannedDuration: TimeInterval
    public var actualDuration: TimeInterval
    public var tasksCompleted: Int
    public var wasInterrupted: Bool

    public init(
        id: UUID = UUID(),
        sessionType: SessionType,
        startedAt: Date,
        completedAt: Date = .now,
        plannedDuration: TimeInterval,
        actualDuration: TimeInterval,
        tasksCompleted: Int = 0,
        wasInterrupted: Bool = false
    ) {
        self.id = id
        self.sessionTypeID = sessionType.id
        self.sessionTitle = sessionType.title
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.plannedDuration = plannedDuration
        self.actualDuration = actualDuration
        self.tasksCompleted = tasksCompleted
        self.wasInterrupted = wasInterrupted
    }
}
