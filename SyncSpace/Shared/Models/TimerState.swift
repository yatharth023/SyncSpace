//
//  TimerState.swift
//  SyncSpace
//
//  Snapshot of the Mac timer. Mac is always the source of truth.
//  iPhone receives these snapshots and renders without owning the timeline.
//

import Foundation

public struct TimerState: Codable, Hashable, Sendable {
    public var sessionType: SessionType
    public var totalDuration: TimeInterval
    public var remainingTime: TimeInterval
    public var isRunning: Bool
    public var startedAt: Date?
    public var lastUpdated: Date

    public init(
        sessionType: SessionType = .focus,
        totalDuration: TimeInterval = SessionType.focus.defaultDuration,
        remainingTime: TimeInterval = SessionType.focus.defaultDuration,
        isRunning: Bool = false,
        startedAt: Date? = nil,
        lastUpdated: Date = .now
    ) {
        self.sessionType = sessionType
        self.totalDuration = totalDuration
        self.remainingTime = remainingTime
        self.isRunning = isRunning
        self.startedAt = startedAt
        self.lastUpdated = lastUpdated
    }

    public var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1.0 - (remainingTime / totalDuration)
    }

    public var elapsed: TimeInterval { max(0, totalDuration - remainingTime) }

    public var isComplete: Bool { remainingTime <= 0 }

    public static let idle = TimerState()
}
