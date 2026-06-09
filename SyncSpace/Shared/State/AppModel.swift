//
//  AppModel.swift
//  SyncSpace
//
//  Top-level @Observable model shared by Mac and iPhone. Holds the timer,
//  audio mix, tasks, and connection layer. Knows whether it is hosting
//  (Mac) or remoting (iPhone), and routes sync messages accordingly.
//

import Foundation
import Observation
import SwiftData

#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
public final class AppModel {

    // MARK: Role

    public let role: PeerRole
    public var isHost: Bool { role == .host }

    // MARK: Synced state

    public var timer: TimerState
    public var mix: AudioMixState
    public var tasks: [TaskItem] = []

    // MARK: Local-only state

    public private(set) var pulse: Double = 0       // continuous breathing 0...1
    public private(set) var todayFocusSeconds: TimeInterval = 0
    public private(set) var sessionsToday: Int = 0
    public private(set) var currentStreakDays: Int = 0
    public private(set) var weekFocusSeconds: TimeInterval = 0
    public private(set) var monthFocusSeconds: TimeInterval = 0

    // MARK: Services

    public let peerManager: PeerManager
    public let audioEngine: AudioEngineService?   // host only
    public var modelContext: ModelContext?        // host only

    // MARK: Settings

    public var customDurationMinutes: Int = 30
    public var hapticsEnabled: Bool = true
    public var soundOnComplete: Bool = true

    // MARK: Private

    private var tickTask: Task<Void, Never>?
    private var pulseTask: Task<Void, Never>?
    private var sessionStartedAt: Date?

    // MARK: Init

    public init(role: PeerRole) {
        self.role = role
        self.peerManager = PeerManager(role: role)
        self.audioEngine = (role == .host) ? AudioEngineService() : nil
        self.timer = .idle
        self.mix = .silent
        self.peerManager.onReceiveMessage = { [weak self] msg in
            self?.handleIncoming(msg)
        }
        startPulse()
    }

    public func attach(modelContext: ModelContext) {
        guard isHost else { return }
        self.modelContext = modelContext
        loadTasksFromStore()
        recalcAnalytics()
    }

    public func startNetworking() {
        peerManager.start()
        if role == .remote {
            // Remote asks for an initial snapshot once the host accepts the link.
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                _ = peerManager.send(.requestSnapshot)
            }
        }
    }

    public func startAudio() {
        audioEngine?.start()
        audioEngine?.apply(mix, fade: 0)
    }

    public func stopAudio() {
        audioEngine?.stop()
    }

    // MARK: Pulse / breathing animation source

    private func startPulse() {
        pulseTask?.cancel()
        pulseTask = Task { [weak self] in
            var t: Double = 0
            while !Task.isCancelled {
                t += 1.0 / 30.0
                let value = (sin(t * 1.4) + 1) * 0.5
                await MainActor.run {
                    self?.pulse = value
                }
                try? await Task.sleep(nanoseconds: 33_000_000)
            }
        }
    }

    // MARK: Timer (host-authoritative)

    public func selectSession(_ type: SessionType) {
        guard isHost else {
            peerManager.send(.command(.selectSession(type)))
            return
        }
        cancelTick()
        let duration: TimeInterval
        if case .custom = type {
            duration = TimeInterval(customDurationMinutes * 60)
        } else {
            duration = type.defaultDuration
        }
        timer = TimerState(
            sessionType: type,
            totalDuration: duration,
            remainingTime: duration,
            isRunning: false,
            startedAt: nil
        )
        broadcastTimer()
    }

    public func setCustomDuration(minutes: Int) {
        let clamped = max(1, min(180, minutes))
        customDurationMinutes = clamped
        if case .custom = timer.sessionType {
            let seconds = TimeInterval(clamped * 60)
            timer.totalDuration = seconds
            timer.remainingTime = seconds
            broadcastTimer()
        }
    }

    public func startTimer() {
        guard isHost else { peerManager.send(.command(.startTimer)); return }
        guard !timer.isRunning else { return }
        if timer.remainingTime <= 0 { timer.remainingTime = timer.totalDuration }
        timer.isRunning = true
        timer.startedAt = .now
        timer.lastUpdated = .now
        sessionStartedAt = .now
        broadcastTimer()
        scheduleTick()
        if hapticsEnabled { HapticManager.shared.trigger(.sessionStarted) }
    }

    public func pauseTimer() {
        guard isHost else { peerManager.send(.command(.pauseTimer)); return }
        guard timer.isRunning else { return }
        timer.isRunning = false
        timer.lastUpdated = .now
        cancelTick()
        broadcastTimer()
        if hapticsEnabled { HapticManager.shared.trigger(.sessionPaused) }
    }

    public func resumeTimer() {
        guard isHost else { peerManager.send(.command(.resumeTimer)); return }
        startTimer()
    }

    public func resetTimer() {
        guard isHost else { peerManager.send(.command(.resetTimer)); return }
        cancelTick()
        timer.isRunning = false
        timer.remainingTime = timer.totalDuration
        timer.startedAt = nil
        timer.lastUpdated = .now
        sessionStartedAt = nil
        broadcastTimer()
    }

    public func skipTimer() {
        guard isHost else { peerManager.send(.command(.skipTimer)); return }
        completeSession(wasInterrupted: true)
    }

    private func scheduleTick() {
        cancelTick()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
                await MainActor.run {
                    self?.tick()
                }
            }
        }
    }

    private func cancelTick() {
        tickTask?.cancel()
        tickTask = nil
    }

    private func tick() {
        guard timer.isRunning else { return }
        let now = Date.now
        let elapsed = now.timeIntervalSince(timer.lastUpdated)
        timer.lastUpdated = now
        timer.remainingTime = max(0, timer.remainingTime - elapsed)
        if timer.remainingTime <= 0 {
            completeSession(wasInterrupted: false)
            return
        }
        // Throttle network updates: only broadcast ~twice a second.
        broadcastTimer()
    }

    private func completeSession(wasInterrupted: Bool) {
        cancelTick()
        let planned = timer.totalDuration
        let actual = wasInterrupted ? (planned - timer.remainingTime) : planned
        let type = timer.sessionType
        timer.isRunning = false
        timer.remainingTime = 0
        timer.lastUpdated = .now
        broadcastTimer()
        peerManager.send(.timerCompleted(type))

        if isHost, let context = modelContext, let started = sessionStartedAt {
            let record = SessionRecord(
                sessionType: type,
                startedAt: started,
                plannedDuration: planned,
                actualDuration: actual,
                tasksCompleted: tasks.filter { $0.isCompleted }.count,
                wasInterrupted: wasInterrupted
            )
            context.insert(record)
            try? context.save()
            peerManager.send(.sessionRecorded(
                plannedSeconds: Int(planned),
                actualSeconds: Int(actual),
                sessionTypeID: type.id
            ))
            recalcAnalytics()
        }

        sessionStartedAt = nil
        if hapticsEnabled { HapticManager.shared.trigger(.sessionCompleted) }
    }

    private func broadcastTimer() {
        guard isHost else { return }
        peerManager.send(.timerUpdate(timer))
    }

    // MARK: Audio mix

    public func setVolume(_ value: Float, for track: AudioTrack) {
        mix[track] = value
        if isHost {
            audioEngine?.apply(mix, fade: 0.05)
            peerManager.sendUnreliable(.audioUpdate(mix))
        } else {
            peerManager.sendUnreliable(.command(.setTrackVolume(track: track, value: value)))
        }
    }

    public func setMasterVolume(_ value: Float) {
        mix.masterVolume = max(0, min(1, value))
        if isHost {
            audioEngine?.apply(mix, fade: 0.05)
            peerManager.sendUnreliable(.audioUpdate(mix))
        } else {
            peerManager.sendUnreliable(.command(.setMasterVolume(value)))
        }
    }

    public func toggleMasterMute() {
        mix.isMasterMuted.toggle()
        if isHost {
            audioEngine?.apply(mix, fade: 0.15)
            peerManager.send(.audioUpdate(mix))
        } else {
            peerManager.send(.command(.toggleMasterMute))
        }
    }

    // MARK: Tasks

    public func addTask(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if isHost {
            let nextIndex = (tasks.map(\.sortIndex).max() ?? 0) + 1
            let item = TaskItem(title: trimmed, sortIndex: nextIndex)
            tasks.append(item)
            persist(item)
            broadcastTasks()
        } else {
            peerManager.send(.command(.addTask(title: trimmed)))
        }
    }

    public func updateTask(_ item: TaskItem) {
        if isHost {
            if let i = tasks.firstIndex(where: { $0.id == item.id }) {
                tasks[i] = item
            } else {
                tasks.append(item)
            }
            persist(item)
            broadcastTasks()
        } else {
            peerManager.send(.command(.updateTask(item)))
        }
    }

    public func toggleTask(_ id: UUID) {
        if isHost {
            guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
            tasks[i].isCompleted.toggle()
            tasks[i].completedAt = tasks[i].isCompleted ? .now : nil
            persist(tasks[i])
            broadcastTasks()
            if hapticsEnabled { HapticManager.shared.trigger(.selection) }
        } else {
            peerManager.send(.command(.toggleTaskCompletion(id: id)))
        }
    }

    public func deleteTask(id: UUID) {
        if isHost {
            tasks.removeAll { $0.id == id }
            if let context = modelContext {
                let descriptor = FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.id == id })
                if let record = try? context.fetch(descriptor).first {
                    context.delete(record)
                    try? context.save()
                }
            }
            broadcastTasks()
        } else {
            peerManager.send(.command(.deleteTask(id: id)))
        }
    }

    public func reorderTasks(_ newOrder: [TaskItem]) {
        guard isHost else { return }
        for (index, item) in newOrder.enumerated() {
            var copy = item
            copy.sortIndex = index
            if let i = tasks.firstIndex(where: { $0.id == item.id }) {
                tasks[i] = copy
            }
            persist(copy)
        }
        broadcastTasks()
    }

    private func broadcastTasks() {
        guard isHost else { return }
        peerManager.send(.taskSnapshot(tasks))
    }

    private func persist(_ item: TaskItem) {
        guard isHost, let context = modelContext else { return }
        let id = item.id
        let descriptor = FetchDescriptor<TaskRecord>(predicate: #Predicate { $0.id == id })
        if let existing = try? context.fetch(descriptor).first {
            existing.apply(item)
        } else {
            context.insert(TaskRecord(
                id: item.id,
                title: item.title,
                isCompleted: item.isCompleted,
                createdAt: item.createdAt,
                completedAt: item.completedAt,
                sortIndex: item.sortIndex
            ))
        }
        try? context.save()
    }

    private func loadTasksFromStore() {
        guard isHost, let context = modelContext else { return }
        let descriptor = FetchDescriptor<TaskRecord>(sortBy: [SortDescriptor(\.sortIndex, order: .forward)])
        if let records = try? context.fetch(descriptor) {
            tasks = records.map(\.snapshot)
        }
    }

    // MARK: Analytics rollup

    public func recalcAnalytics() {
        guard isHost, let context = modelContext else { return }
        let calendar = Calendar.current
        let now = Date.now
        let descriptor = FetchDescriptor<SessionRecord>(sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
        guard let records = try? context.fetch(descriptor) else { return }

        let startOfToday = calendar.startOfDay(for: now)
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? startOfToday

        let todayRecords = records.filter { $0.completedAt >= startOfToday }
        let weekRecords = records.filter { $0.completedAt >= startOfWeek }
        let monthRecords = records.filter { $0.completedAt >= startOfMonth }

        todayFocusSeconds = todayRecords.reduce(0) { $0 + $1.actualDuration }
        weekFocusSeconds = weekRecords.reduce(0) { $0 + $1.actualDuration }
        monthFocusSeconds = monthRecords.reduce(0) { $0 + $1.actualDuration }
        sessionsToday = todayRecords.count
        currentStreakDays = calculateStreak(records: records, calendar: calendar, now: now)
    }

    private func calculateStreak(records: [SessionRecord], calendar: Calendar, now: Date) -> Int {
        guard !records.isEmpty else { return 0 }
        var streak = 0
        var cursor = calendar.startOfDay(for: now)
        let daysWithFocus: Set<Date> = Set(records.map { calendar.startOfDay(for: $0.completedAt) })
        while daysWithFocus.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    // MARK: Incoming message routing

    private func handleIncoming(_ message: SyncMessage) {
        switch message {
        case .timerUpdate(let state):
            if !isHost { timer = state }
        case .timerCompleted:
            if !isHost, hapticsEnabled { HapticManager.shared.trigger(.sessionCompleted) }
        case .audioUpdate(let state):
            if !isHost { mix = state }
        case .taskSnapshot(let items):
            if !isHost { tasks = items.sorted(by: { $0.sortIndex < $1.sortIndex }) }
        case .sessionRecorded:
            break
        case .requestSnapshot:
            if isHost {
                peerManager.send(.timerUpdate(timer))
                peerManager.send(.audioUpdate(mix))
                peerManager.send(.taskSnapshot(tasks))
            }
        case .command(let cmd):
            if isHost { execute(cmd) }
        case .handshake:
            if isHost {
                peerManager.send(.timerUpdate(timer))
                peerManager.send(.audioUpdate(mix))
                peerManager.send(.taskSnapshot(tasks))
            }
        }
    }

    private func execute(_ command: RemoteCommand) {
        switch command {
        case .startTimer:                          startTimer()
        case .pauseTimer:                          pauseTimer()
        case .resumeTimer:                         resumeTimer()
        case .resetTimer:                          resetTimer()
        case .skipTimer:                           skipTimer()
        case .selectSession(let type):             selectSession(type)
        case .setTrackVolume(let track, let v):    setVolume(v, for: track)
        case .setMasterVolume(let v):              setMasterVolume(v)
        case .toggleMasterMute:                    toggleMasterMute()
        case .addTask(let title):                  addTask(title: title)
        case .updateTask(let item):                updateTask(item)
        case .deleteTask(let id):                  deleteTask(id: id)
        case .toggleTaskCompletion(let id):        toggleTask(id)
        }
    }
}
