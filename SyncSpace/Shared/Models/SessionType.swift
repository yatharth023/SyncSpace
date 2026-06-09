//
//  SessionType.swift
//  SyncSpace
//
//  Built-in focus session presets. Custom durations use `.custom(seconds:)`.
//

import Foundation

public enum SessionType: Codable, Hashable, Sendable, Identifiable {
    case focus
    case deepWork
    case sprint
    case custom(seconds: Int)

    public var id: String {
        switch self {
        case .focus:                return "focus"
        case .deepWork:             return "deepWork"
        case .sprint:               return "sprint"
        case .custom(let seconds):  return "custom-\(seconds)"
        }
    }

    public var title: String {
        switch self {
        case .focus:        return "Focus Session"
        case .deepWork:     return "Deep Work"
        case .sprint:       return "Sprint"
        case .custom:       return "Custom"
        }
    }

    public var shortTitle: String {
        switch self {
        case .focus:        return "Focus"
        case .deepWork:     return "Deep"
        case .sprint:       return "Sprint"
        case .custom:       return "Custom"
        }
    }

    public var symbol: String {
        switch self {
        case .focus:        return "scope"
        case .deepWork:     return "brain.head.profile"
        case .sprint:       return "bolt.fill"
        case .custom:       return "slider.horizontal.3"
        }
    }

    public var defaultDuration: TimeInterval {
        switch self {
        case .focus:                return 25 * 60
        case .deepWork:             return 50 * 60
        case .sprint:               return 15 * 60
        case .custom(let seconds):  return TimeInterval(seconds)
        }
    }

    public static let presets: [SessionType] = [.focus, .deepWork, .sprint]
}
