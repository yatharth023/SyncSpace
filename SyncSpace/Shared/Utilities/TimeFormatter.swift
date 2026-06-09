//
//  TimeFormatter.swift
//  SyncSpace
//
//  Display helpers for durations.
//

import Foundation

public enum TimeFormatter {

    public static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public static func compact(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "\(total)s"
    }

    public static func minutesLabel(_ interval: TimeInterval) -> String {
        let mins = Int((interval / 60).rounded())
        return "\(mins) min"
    }
}
