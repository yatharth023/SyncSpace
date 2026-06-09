//
//  SyncMessage.swift
//  SyncSpace
//
//  Discriminated union sent over MultipeerConnectivity. Designed to stay
//  small and incremental; never send the full app state on every change.
//

import Foundation

public enum SyncMessage: Codable, Sendable {

    // Mac -> iPhone broadcasts.
    case timerUpdate(TimerState)
    case timerCompleted(SessionType)
    case audioUpdate(AudioMixState)
    case taskSnapshot([TaskItem])
    case sessionRecorded(plannedSeconds: Int, actualSeconds: Int, sessionTypeID: String)

    // iPhone -> Mac commands.
    case command(RemoteCommand)
    case requestSnapshot

    // Bidirectional.
    case handshake(role: PeerRole, deviceName: String, appVersion: String)
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
