//
//  HapticManager.swift
//  SyncSpace
//
//  Cross-platform haptics. On iOS we drive CoreHaptics for rich patterns and
//  fall back to UIImpactFeedbackGenerator. On macOS we use NSHapticFeedback
//  where available. Anywhere else this is a silent no-op.
//

import Foundation

#if canImport(CoreHaptics)
import CoreHaptics
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

public enum HapticEvent {
    case sessionStarted
    case sessionPaused
    case sessionResumed
    case sessionCompleted
    case tap
    case selection
    case warning
}

@MainActor
public final class HapticManager {

    public static let shared = HapticManager()

    #if canImport(CoreHaptics)
    private var engine: CHHapticEngine?
    private let supportsHaptics: Bool = {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }()
    #endif

    private init() {
        prepare()
    }

    public func prepare() {
        #if canImport(CoreHaptics)
        guard supportsHaptics, engine == nil else { return }
        do {
            engine = try CHHapticEngine()
            engine?.isAutoShutdownEnabled = true
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            engine?.stoppedHandler = { _ in /* will restart on next trigger */ }
            try engine?.start()
        } catch {
            engine = nil
        }
        #endif
    }

    public func trigger(_ event: HapticEvent) {
        #if canImport(CoreHaptics) && canImport(UIKit)
        if supportsHaptics, let engine {
            do {
                let pattern = try patternFor(event)
                let player = try engine.makePlayer(with: pattern)
                try engine.start()
                try player.start(atTime: 0)
                return
            } catch {
                // Fall through to UIKit feedback generators below.
            }
        }
        fallbackUIKit(event)
        #elseif canImport(UIKit)
        fallbackUIKit(event)
        #elseif canImport(AppKit)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        #endif
    }

    #if canImport(UIKit)
    private func fallbackUIKit(_ event: HapticEvent) {
        switch event {
        case .sessionStarted, .sessionResumed:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .sessionPaused:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .sessionCompleted:
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
        case .tap, .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }
    #endif

    #if canImport(CoreHaptics)
    private func patternFor(_ event: HapticEvent) throws -> CHHapticPattern {
        switch event {
        case .sessionStarted:
            return try CHHapticPattern(events: [
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [
                                .init(parameterID: .hapticIntensity, value: 0.7),
                                .init(parameterID: .hapticSharpness, value: 0.4),
                              ],
                              relativeTime: 0),
                CHHapticEvent(eventType: .hapticContinuous,
                              parameters: [
                                .init(parameterID: .hapticIntensity, value: 0.4),
                                .init(parameterID: .hapticSharpness, value: 0.2),
                              ],
                              relativeTime: 0.08,
                              duration: 0.18),
            ], parameters: [])
        case .sessionPaused:
            return try CHHapticPattern(events: [
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [
                                .init(parameterID: .hapticIntensity, value: 0.5),
                                .init(parameterID: .hapticSharpness, value: 0.2),
                              ],
                              relativeTime: 0),
            ], parameters: [])
        case .sessionResumed:
            return try CHHapticPattern(events: [
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [
                                .init(parameterID: .hapticIntensity, value: 0.6),
                                .init(parameterID: .hapticSharpness, value: 0.5),
                              ],
                              relativeTime: 0),
            ], parameters: [])
        case .sessionCompleted:
            // Distinct double-bloom pattern.
            return try CHHapticPattern(events: [
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [
                                .init(parameterID: .hapticIntensity, value: 1.0),
                                .init(parameterID: .hapticSharpness, value: 0.8),
                              ],
                              relativeTime: 0),
                CHHapticEvent(eventType: .hapticContinuous,
                              parameters: [
                                .init(parameterID: .hapticIntensity, value: 0.7),
                                .init(parameterID: .hapticSharpness, value: 0.3),
                              ],
                              relativeTime: 0.12,
                              duration: 0.4),
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [
                                .init(parameterID: .hapticIntensity, value: 1.0),
                                .init(parameterID: .hapticSharpness, value: 0.9),
                              ],
                              relativeTime: 0.65),
            ], parameters: [])
        case .tap, .selection:
            return try CHHapticPattern(events: [
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [
                                .init(parameterID: .hapticIntensity, value: 0.35),
                                .init(parameterID: .hapticSharpness, value: 0.4),
                              ],
                              relativeTime: 0),
            ], parameters: [])
        case .warning:
            return try CHHapticPattern(events: [
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [
                                .init(parameterID: .hapticIntensity, value: 0.8),
                                .init(parameterID: .hapticSharpness, value: 0.9),
                              ],
                              relativeTime: 0),
                CHHapticEvent(eventType: .hapticTransient,
                              parameters: [
                                .init(parameterID: .hapticIntensity, value: 0.8),
                                .init(parameterID: .hapticSharpness, value: 0.9),
                              ],
                              relativeTime: 0.15),
            ], parameters: [])
        }
    }
    #endif
}
