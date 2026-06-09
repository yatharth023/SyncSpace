//
//  AudioMixState.swift
//  SyncSpace
//
//  Per-track volumes plus master gain. Volumes are clamped 0...1.
//

import Foundation

public struct AudioMixState: Codable, Hashable, Sendable {
    public var rainVolume: Float
    public var whiteNoiseVolume: Float
    public var cafeVolume: Float
    public var forestVolume: Float
    public var lofiVolume: Float
    public var masterVolume: Float
    public var isMasterMuted: Bool

    public init(
        rainVolume: Float = 0,
        whiteNoiseVolume: Float = 0,
        cafeVolume: Float = 0,
        forestVolume: Float = 0,
        lofiVolume: Float = 0,
        masterVolume: Float = 0.8,
        isMasterMuted: Bool = false
    ) {
        self.rainVolume = rainVolume
        self.whiteNoiseVolume = whiteNoiseVolume
        self.cafeVolume = cafeVolume
        self.forestVolume = forestVolume
        self.lofiVolume = lofiVolume
        self.masterVolume = masterVolume
        self.isMasterMuted = isMasterMuted
    }

    public subscript(track: AudioTrack) -> Float {
        get {
            switch track {
            case .rain:        return rainVolume
            case .whiteNoise:  return whiteNoiseVolume
            case .cafe:        return cafeVolume
            case .forest:      return forestVolume
            case .lofi:        return lofiVolume
            }
        }
        set {
            let clamped = max(0, min(1, newValue))
            switch track {
            case .rain:        rainVolume = clamped
            case .whiteNoise:  whiteNoiseVolume = clamped
            case .cafe:        cafeVolume = clamped
            case .forest:      forestVolume = clamped
            case .lofi:        lofiVolume = clamped
            }
        }
    }

    public var activeTracks: [AudioTrack] {
        AudioTrack.allCases.filter { self[$0] > 0.01 }
    }

    public var combinedLevel: Float {
        guard !isMasterMuted else { return 0 }
        let sum = AudioTrack.allCases.reduce(Float(0)) { $0 + self[$1] }
        return min(1, sum / Float(AudioTrack.allCases.count) * masterVolume * 2)
    }

    public static let silent = AudioMixState()
}
