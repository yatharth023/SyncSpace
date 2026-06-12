//
//  SyncMessage.swift
//  SyncSpace
//

import Foundation

public enum SyncMessage: Codable, Sendable {

    // Mac → iPhone broadcasts.
    case timerUpdate(TimerState)
    case timerCompleted(SessionType)
    case audioUpdate(AudioMixState)
    case taskSnapshot([TaskItem])
    case analyticsSnapshot(AnalyticsSnapshot)
    case sessionRecorded(plannedSeconds: Int, actualSeconds: Int, sessionTypeID: String)

    // iPhone → Mac commands.
    case command(RemoteCommand)
    case requestSnapshot

    // Bidirectional.
    case handshake(role: PeerRole, deviceName: String, appVersion: String)
    case heartbeat
}

public struct AnalyticsSnapshot: Codable, Hashable, Sendable {
    public var today: TimeInterval
    public var week: TimeInterval
    public var month: TimeInterval
    public var sessionsToday: Int
    public var streak: Int

    public init(today: TimeInterval = 0,
                week: TimeInterval = 0,
                month: TimeInterval = 0,
                sessionsToday: Int = 0,
                streak: Int = 0) {
        self.today = today
        self.week = week
        self.month = month
        self.sessionsToday = sessionsToday
        self.streak = streak
    }

    public static let empty = AnalyticsSnapshot()
}

public enum RemoteCommand: Codable, Sendable {
    case startTimer
    case pauseTimer
    case resumeTimer
    case resetTimer
    case skipTimer
    case selectSession(SessionType)
    case setTrackVolume(track: AudioTrack, value: Float)
    case setMasterVolume(Float)
    case toggleMasterMute
    case addTask(title: String)
    case updateTask(TaskItem)
    case deleteTask(id: UUID)
    case toggleTaskCompletion(id: UUID)
}

public enum PeerRole: String, Codable, Sendable {
    case host       // Mac
    case remote     // iPhone
}
