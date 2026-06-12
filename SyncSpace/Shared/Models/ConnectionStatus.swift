//
//  ConnectionStatus.swift
//  SyncSpace
//

import Foundation
import SwiftUI

public enum ConnectionStatus: String, Codable, Sendable {
    case offline
    case advertising
    case browsing
    case connecting
    case reconnecting
    case connected

    public var title: String {
        switch self {
        case .offline:       return "Offline"
        case .advertising:   return "Discoverable"
        case .browsing:      return "Searching"
        case .connecting:    return "Connecting"
        case .reconnecting:  return "Reconnecting"
        case .connected:     return "Connected"
        }
    }

    public var buttonLabel: String {
        switch self {
        case .offline:       return "Connect"
        case .advertising,
             .browsing:      return "Searching…"
        case .connecting:    return "Connecting…"
        case .reconnecting:  return "Reconnecting…"
        case .connected:     return "Connected"
        }
    }

    public var symbol: String {
        switch self {
        case .offline:       return "wifi.slash"
        case .advertising:   return "antenna.radiowaves.left.and.right"
        case .browsing:      return "magnifyingglass"
        case .connecting:    return "arrow.triangle.2.circlepath"
        case .reconnecting:  return "arrow.triangle.2.circlepath"
        case .connected:     return "checkmark.circle.fill"
        }
    }

    public var tint: Color {
        switch self {
        case .offline:       return Color.secondary
        case .advertising,
             .browsing,
             .connecting,
             .reconnecting:  return Color.orange
        case .connected:     return Color.green
        }
    }

    public var isInFlight: Bool {
        switch self {
        case .connecting, .reconnecting, .browsing, .advertising: return true
        default: return false
        }
    }
}
