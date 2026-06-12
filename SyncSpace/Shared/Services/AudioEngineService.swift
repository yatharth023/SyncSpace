//
//  AudioEngineService.swift
//  SyncSpace
//
//  Ambient audio mixer. Five channels of procedurally-generated audio that
//  loop seamlessly via AVAudioPlayerNode's `.loops` option.
//
//  Design notes (why this version exists):
//
//   • The earlier version streamed 0.5s buffers and re-scheduled the next
//     one from a MainActor hop inside the audio completion callback. When
//     the main thread fell behind (e.g. during a slider drag), the next
//     buffer would arrive late and the listener heard a dropout.
//   • Volume changes used 12 enqueued `DispatchQueue.main.asyncAfter` blocks
//     to "fade". With high-frequency slider drags, these stacked up and
//     fought each other, producing audible jumps.
//
//  New behaviour:
//
//   • Each channel pre-renders a single ~10s loop buffer ONCE on start.
//   • That buffer is scheduled with `.loops`; audio playback is then
//     completely independent of the main thread. No callbacks, no glitches.
//   • Volume changes write directly to `AVAudioMixerNode.outputVolume`
//     which is parameter-smoothed by Core Audio at the sample level — no
//     manual fade pump is needed.
//

import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
public final class AudioEngineService {

    public private(set) var isRunning: Bool = false
    public private(set) var lastError: String?

    private let engine = AVAudioEngine()
    private let mainMixer: AVAudioMixerNode
    private var channels: [AudioTrack: Channel] = [:]
    private let format: AVAudioFormat
    private let loopSeconds: Double = 10

    public init() {
        self.mainMixer = engine.mainMixerNode
        self.format = engine.outputNode.outputFormat(forBus: 0)
    }

    // MARK: Lifecycle

    public func start() {
        guard !isRunning else { return }
        do {
            try installChannelsIfNeeded()
            engine.prepare()
            try engine.start()
            for channel in channels.values {
                channel.beginLoop()
            }
            isRunning = true
            lastError = nil
        } catch {
            lastError = "Audio engine failed: \(error.localizedDescription)"
            isRunning = false
        }
    }

    public func stop() {
        guard isRunning else { return }
        for channel in channels.values {
            channel.player.stop()
        }
        engine.stop()
        isRunning = false
    }

    // MARK: Mixing — write straight to the per-channel mixer.

    /// Apply the entire mix snapshot. Cheap: 5 immediate writes to AVAudioMixerNode.
    public func apply(_ mix: AudioMixState) {
        let master = effectiveMaster(mix)
        for track in AudioTrack.allCases {
            channels[track]?.mixer.outputVolume = mix[track] * master
        }
    }

    /// Update a single track. Used by the slider drag path so the other four
    /// channels are not touched.
    public func setVolume(_ value: Float, for track: AudioTrack, master: Float, muted: Bool) {
        let mixerVolume = muted ? 0 : value * master
        channels[track]?.mixer.outputVolume = max(0, min(1, mixerVolume))
    }

    /// Update only master gain across all channels without recomputing each.
    public func setMasterVolume(_ value: Float, mix: AudioMixState) {
        let master = mix.isMasterMuted ? 0 : max(0, min(1, value))
        for track in AudioTrack.allCases {
            channels[track]?.mixer.outputVolume = mix[track] * master
        }
    }

    private func effectiveMaster(_ mix: AudioMixState) -> Float {
        mix.isMasterMuted ? 0 : mix.masterVolume
    }

    // MARK: Channel install

    private func installChannelsIfNeeded() throws {
        guard channels.isEmpty else { return }
        let frames = AVAudioFrameCount(loopSeconds * format.sampleRate)
        for track in AudioTrack.allCases {
            let player = AVAudioPlayerNode()
            let mixer = AVAudioMixerNode()
            engine.attach(player)
            engine.attach(mixer)
            engine.connect(player, to: mixer, format: format)
            engine.connect(mixer, to: mainMixer, format: format)
            mixer.outputVolume = 0

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
                throw NSError(domain: "syncspace.audio", code: 1)
            }
            buffer.frameLength = frames
            LoopRenderer.render(track: track, into: buffer, sampleRate: format.sampleRate)
            channels[track] = Channel(track: track, player: player, mixer: mixer, loop: buffer)
        }
    }
}

// MARK: - Channel

private final class Channel {
    let track: AudioTrack
    let player: AVAudioPlayerNode
    let mixer: AVAudioMixerNode
    let loop: AVAudioPCMBuffer

    init(track: AudioTrack, player: AVAudioPlayerNode, mixer: AVAudioMixerNode, loop: AVAudioPCMBuffer) {
        self.track = track
        self.player = player
        self.mixer = mixer
        self.loop = loop
    }

    func beginLoop() {
        // `.loops` makes Core Audio repeat the buffer indefinitely with no
        // main-thread involvement and no schedule callbacks.
        player.scheduleBuffer(loop, at: nil, options: .loops, completionCallbackType: .dataPlayedBack) { _ in
            // Intentionally empty — buffer loops forever; nothing to schedule.
        }
        player.play()
    }
}

// MARK: - Loop renderer
//
// Pre-renders one buffer per track. Crossfades the wrap-around for tracks
// where a hard edge would be audible. Stateless once finished.

private enum LoopRenderer {

    static func render(track: AudioTrack, into buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard let data = buffer.floatChannelData else { return }
        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)

        var generator = SignalGenerator(track: track, sampleRate: sampleRate)
        // Render the signal.
        for frame in 0..<frameCount {
            let sample = generator.nextSample()
            for ch in 0..<channelCount {
                data[ch][frame] = sample
            }
        }

        // Apply equal-power crossfade on the boundary so the loop is seamless
        // for tonal content. ~120ms is short enough to be inaudible but long
        // enough to hide phase mismatch.
        let fadeFrames = min(frameCount / 16, Int(0.12 * sampleRate))
        if fadeFrames > 8 {
            for i in 0..<fadeFrames {
                let t = Float(i) / Float(fadeFrames)
                let endIdx = frameCount - fadeFrames + i
                let startIdx = i
                let head = data[0][startIdx]
                let tail = data[0][endIdx]
                let blendedStart = head * t + tail * (1 - t)
                let blendedEnd = head * (1 - t) + tail * t
                for ch in 0..<channelCount {
                    data[ch][startIdx] = blendedStart
                    data[ch][endIdx] = blendedEnd
                }
            }
        }
    }
}

// MARK: - Signal generation

private struct SignalGenerator {

    let track: AudioTrack
    let sampleRate: Double

    // Track-specific state
    private var pink = PinkNoise()
    private var brownState: Float = 0
    private var lpfState: Float = 0
    private var hpfState: Float = 0
    private var prevPink: Float = 0
    private var phase: Double = 0
    private var phase2: Double = 0
    private var windPhase: Double = 0
    private var chirpRemaining: Int = 0
    private var clinkRemaining: Int = 0
    private var lofiTime: Double = 0

    init(track: AudioTrack, sampleRate: Double) {
        self.track = track
        self.sampleRate = sampleRate
    }

    mutating func nextSample() -> Float {
        switch track {
        case .rain:        return rain()
        case .whiteNoise:  return whiteNoise()
        case .cafe:        return cafe()
        case .forest:      return forest()
        case .lofi:        return lofi()
        }
    }

    private mutating func rain() -> Float {
        var s = pink.next() * 0.6
        let alpha: Float = 0.18
        lpfState += alpha * (s - lpfState)
        s = lpfState
        if Int.random(in: 0..<2000) == 0 {
            s += Float.random(in: -0.4...0.4)
        }
        return s * 0.7
    }

    private mutating func whiteNoise() -> Float {
        Float.random(in: -1...1) * 0.4
    }

    private mutating func cafe() -> Float {
        let w = Float.random(in: -1...1)
        brownState = (brownState + 0.02 * w).clamped(to: -1...1)
        var rumble = brownState * 0.7
        let p = pink.next()
        let hpfAlpha: Float = 0.06
        hpfState = hpfAlpha * (hpfState + p - prevPink)
        prevPink = p
        let chatter = hpfState * 0.5
        clinkRemaining -= 1
        if clinkRemaining <= 0, Int.random(in: 0..<8000) == 0 {
            rumble += Float.random(in: -0.2...0.2)
            clinkRemaining = 200
        }
        return (rumble + chatter) * 0.6
    }

    private mutating func forest() -> Float {
        var wind = pink.next() * 0.5
        let alpha: Float = 0.10
        lpfState += alpha * (wind - lpfState)
        wind = lpfState
        windPhase += 2 * .pi * 0.07 / sampleRate
        if windPhase > 2 * .pi { windPhase -= 2 * .pi }
        wind *= Float(0.6 + 0.4 * sin(windPhase))
        var chirp: Float = 0
        if Int.random(in: 0..<24_000) == 0 { chirpRemaining = 1200 }
        if chirpRemaining > 0 {
            let t = Double(1200 - chirpRemaining) / 1200.0
            let freq = 1800.0 + 600.0 * sin(t * 12)
            phase2 += 2 * .pi * freq / sampleRate
            chirp = Float(sin(phase2)) * Float(0.18 * (1 - t))
            chirpRemaining -= 1
        }
        return (wind * 0.9 + chirp) * 0.7
    }

    private mutating func lofi() -> Float {
        lofiTime += 1.0 / sampleRate
        let fundamental: Double = 110.0
        let chord: [Double] = [1.0, 1.1892, 1.4983, 1.7818]
        var s: Double = 0
        for (i, ratio) in chord.enumerated() {
            phase = 2 * .pi * fundamental * ratio * lofiTime
            let detune = 1.0 + 0.0015 * sin(2 * .pi * 0.13 * lofiTime + Double(i))
            s += sin(phase * detune) * 0.18 * (1 - Double(i) * 0.15)
        }
        let trem = 0.85 + 0.15 * sin(2 * .pi * 0.25 * lofiTime)
        s *= trem
        s += Double.random(in: -0.05...0.05)
        return Float(tanh(s * 1.2)) * 0.55
    }
}

private struct PinkNoise {
    private var b0: Float = 0
    private var b1: Float = 0
    private var b2: Float = 0
    private var b3: Float = 0
    private var b4: Float = 0
    private var b5: Float = 0
    private var b6: Float = 0

    mutating func next() -> Float {
        let white = Float.random(in: -1...1)
        b0 = 0.99886 * b0 + white * 0.0555179
        b1 = 0.99332 * b1 + white * 0.0750759
        b2 = 0.96900 * b2 + white * 0.1538520
        b3 = 0.86650 * b3 + white * 0.3104856
        b4 = 0.55000 * b4 + white * 0.5329522
        b5 = -0.7616 * b5 - white * 0.0168980
        let pink = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362
        b6 = white * 0.115926
        return pink * 0.11
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
