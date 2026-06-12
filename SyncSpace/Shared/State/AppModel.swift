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

    // On the host these are recomputed from SwiftData via `recalcAnalytics`.
    // On the remote they are written from `.analyticsSnapshot` messages.
    public internal(set) var todayFocusSeconds: TimeInterval = 0
    public internal(set) var sessionsToday: Int = 0
    public internal(set) var currentStreakDays: Int = 0
    public internal(set) var weekFocusSeconds: TimeInterval = 0
    public internal(set) var monthFocusSeconds: TimeInterval = 0

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
    private var sessionStartedAt: Date?

    // MARK: Completion event (drives the completion sheet)

    public var lastCompletedSession: SessionType?
    public var lastCompletionAt: Date?

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
        self.peerManager.onConnect = { [weak self] in
            self?.handleConnect()
        }
    }

    public func attach(modelContext: ModelContext) {
        guard isHost else { return }
        self.modelContext = modelContext
        loadTasksFromStore()
        recalcAnalytics()
    }

    public func startNetworking() {
        peerManager.start()
    }

    /// Called when the MC session transitions to `.connected`. Host broadcasts
    /// a full snapshot so the remote's UI is correct from the first frame.
    /// Remote sends `.requestSnapshot` as belt-and-braces in case the host
    /// callback fires before its delegate is fully wired.
    private func handleConnect() {
        if isHost {
            broadcastFullSnapshot()
        } else {
            peerManager.send(.requestSnapshot)
        }
    }

    private func broadcastFullSnapshot() {
        peerManager.send(.timerUpdate(timer))
        peerManager.send(.audioUpdate(mix))
        peerManager.send(.taskSnapshot(tasks))
        peerManager.send(.analyticsSnapshot(currentAnalyticsSnapshot()))
    }

    private func currentAnalyticsSnapshot() -> AnalyticsSnapshot {
        AnalyticsSnapshot(
            today: todayFocusSeconds,
            week: weekFocusSeconds,
            month: monthFocusSeconds,
            sessionsToday: sessionsToday,
            streak: currentStreakDays
        )
    }

    public func startAudio() {
        audioEngine?.start()
        audioEngine?.apply(mix)
    }

    public func stopAudio() {
        audioEngine?.stop()
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
            // 1Hz on the model is enough — the UI uses TimelineView at higher
            // rate to smoothly interpolate the displayed seconds.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run { self?.tick() }
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
            // Broadcast the updated analytics so the remote's stat cards
            // stay current without polling.
            peerManager.send(.analyticsSnapshot(currentAnalyticsSnapshot()))
        }

        sessionStartedAt = nil
        if hapticsEnabled { HapticManager.shared.trigger(.sessionCompleted) }

        // Trigger the completion experience for a natural finish only —
        // skipped sessions don't pop the sheet.
        if !wasInterrupted {
            lastCompletedSession = type
            lastCompletionAt = .now
            if soundOnComplete {
                NotificationService.playCompletionSound()
            }
            Task { await NotificationService.notifyCompletion(of: type) }
        }
    }

    // MARK: Completion sheet helpers

    public func dismissCompletion() {
        lastCompletedSession = nil
    }

    public func startBreakAfterCompletion(minutes: Int = 5) {
        guard isHost else {
            peerManager.send(.command(.selectSession(.custom(seconds: minutes * 60))))
            return
        }
        selectSession(.custom(seconds: minutes * 60))
        startTimer()
        dismissCompletion()
    }

    public func restartLastSession() {
        guard let type = lastCompletedSession else { return }
        if isHost {
            selectSession(type)
            startTimer()
        } else {
            peerManager.send(.command(.selectSession(type)))
            peerManager.send(.command(.startTimer))
        }
        dismissCompletion()
    }

    private func broadcastTimer() {
        guard isHost else { return }
        peerManager.send(.timerUpdate(timer))
    }

    // MARK: Audio mix

    public func setVolume(_ value: Float, for track: AudioTrack) {
        let clamped = max(0, min(1, value))
        mix[track] = clamped
        if isHost {
            audioEngine?.setVolume(
                clamped,
                for: track,
                master: mix.masterVolume,
                muted: mix.isMasterMuted
            )
            peerManager.sendUnreliable(.audioUpdate(mix))
        } else {
            peerManager.sendUnreliable(.command(.setTrackVolume(track: track, value: clamped)))
        }
    }

    public func setMasterVolume(_ value: Float) {
        let clamped = max(0, min(1, value))
        mix.masterVolume = clamped
        if isHost {
            audioEngine?.setMasterVolume(clamped, mix: mix)
            peerManager.sendUnreliable(.audioUpdate(mix))
        } else {
            peerManager.sendUnreliable(.command(.setMasterVolume(clamped)))
        }
    }

    public func toggleMasterMute() {
        mix.isMasterMuted.toggle()
        if isHost {
            audioEngine?.apply(mix)
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

    // MARK: Session-history maintenance

    public func clearSessionHistory() {
        guard isHost, let context = modelContext else { return }
        let descriptor = FetchDescriptor<SessionRecord>()
        if let records = try? context.fetch(descriptor) {
            records.forEach(context.delete)
            try? context.save()
            recalcAnalytics()
        }
    }

    public func exportSessionHistory() throws -> URL {
        guard isHost, let context = modelContext else {
            throw NSError(domain: "syncspace.export", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Export only available on host."])
        }
        let descriptor = FetchDescriptor<SessionRecord>(sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
        let records = (try? context.fetch(descriptor)) ?? []
        let payload = records.map { record -> [String: Any] in
            [
                "id": record.id.uuidString,
                "sessionTypeID": record.sessionTypeID,
                "sessionTitle": record.sessionTitle,
                "startedAt": ISO8601DateFormatter().string(from: record.startedAt),
                "completedAt": ISO8601DateFormatter().string(from: record.completedAt),
                "plannedDuration": record.plannedDuration,
                "actualDuration": record.actualDuration,
                "tasksCompleted": record.tasksCompleted,
                "wasInterrupted": record.wasInterrupted
            ]
        }
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let dateStr = formatter.string(from: .now)
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SyncSpace-history-\(dateStr).json")
        try data.write(to: url, options: .atomic)
        return url
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
        case .timerCompleted(let type):
            if !isHost {
                if hapticsEnabled { HapticManager.shared.trigger(.sessionCompleted) }
                lastCompletedSession = type
                lastCompletionAt = .now
                Task { await NotificationService.notifyCompletion(of: type) }
            }
        case .audioUpdate(let state):
            if !isHost { mix = state }
        case .taskSnapshot(let items):
            if !isHost { tasks = items.sorted(by: { $0.sortIndex < $1.sortIndex }) }
        case .analyticsSnapshot(let snap):
            if !isHost {
                todayFocusSeconds = snap.today
                weekFocusSeconds = snap.week
                monthFocusSeconds = snap.month
                sessionsToday = snap.sessionsToday
                currentStreakDays = snap.streak
            }
        case .sessionRecorded:
            break
        case .requestSnapshot:
            if isHost { broadcastFullSnapshot() }
        case .command(let cmd):
            if isHost { execute(cmd) }
        case .handshake:
            if isHost { broadcastFullSnapshot() }
        case .heartbeat:
            break   // PeerManager already records the timestamp.
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
