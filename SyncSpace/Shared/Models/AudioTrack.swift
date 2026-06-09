//
//  AudioTrack.swift
//  SyncSpace
//
//  Ambient track catalogue. Each track corresponds to a procedurally
//  generated signal so the app ships without bundled audio assets.
//

import Foundation
import SwiftUI

public enum AudioTrack: String, CaseIterable, Codable, Sendable, Identifiable {
    case rain
    case whiteNoise
    case cafe
    case forest
    case lofi

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .rain:        return "Rain"
        case .whiteNoise:  return "White Noise"
        case .cafe:        return "Cafe"
        case .forest:      return "Forest"
        case .lofi:        return "LoFi"
        }
    }

    public var subtitle: String {
        switch self {
        case .rain:        return "Soft showers"
        case .whiteNoise:  return "Steady hush"
        case .cafe:        return "Murmured chatter"
        case .forest:      return "Wind & leaves"
        case .lofi:        return "Warm chords"
        }
    }

    public var symbol: String {
        switch self {
        case .rain:        return "cloud.rain.fill"
        case .whiteNoise:  return "waveform"
        case .cafe:        return "cup.and.saucer.fill"
        case .forest:      return "tree.fill"
        case .lofi:        return "music.note"
        }
    }

    public var tint: Color {
        switch self {
        case .rain:        return Color(red: 0.40, green: 0.65, blue: 0.95)
        case .whiteNoise:  return Color(red: 0.70, green: 0.75, blue: 0.85)
        case .cafe:        return Color(red: 0.85, green: 0.55, blue: 0.35)
        case .forest:      return Color(red: 0.40, green: 0.78, blue: 0.55)
        case .lofi:        return Color(red: 0.78, green: 0.55, blue: 0.95)
        }
    }
}
