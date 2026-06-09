//
//  ConnectionStatus.swift
//  SyncSpace
//
//  High-level peering state surfaced to the UI.
//

import Foundation
import SwiftUI

public enum ConnectionStatus: String, Codable, Sendable {
    case offline
    case advertising
    case browsing
    case connecting
    case connected

    public var title: String {
        switch self {
        case .offline:      return "Offline"
        case .advertising:  return "Discoverable"
        case .browsing:     return "Searching"
        case .connecting:   return "Pairing"
        case .connected:    return "Linked"
        }
    }

    public var symbol: String {
        switch self {
        case .offline:      return "wifi.slash"
        case .advertising:  return "antenna.radiowaves.left.and.right"
        case .browsing:     return "magnifyingglass"
        case .connecting:   return "arrow.triangle.2.circlepath"
        case .connected:    return "link"
        }
    }

    public var tint: Color {
        switch self {
        case .offline:      return Color.secondary
        case .advertising,
             .browsing,
             .connecting:   return Color.orange
        case .connected:    return Color.green
        }
    }
}
