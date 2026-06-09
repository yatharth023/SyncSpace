//
//  AudioEngineService.swift
//  SyncSpace
//
//  AVAudioEngine-powered ambient mixer. Procedurally generates each channel
//  using DSP (pink noise + filtering, sine partials, etc.) so the app ships
//  without bundled assets. Each channel has its own AVAudioPlayerNode driving
//  a continuous schedule of generated buffers.
//
//  Only the Mac runs this engine. The iPhone never produces audio; it just
//  visualises the active mix it receives over MultipeerConnectivity.
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
            channels.values.forEach { $0.player.play() }
            for channel in channels.values { channel.scheduleNextBufferIfNeeded() }
            isRunning = true
        } catch {
            lastError = "Audio engine failed: \(error.localizedDescription)"
            isRunning = false
        }
    }

    public func stop() {
        guard isRunning else { return }
        channels.values.forEach { $0.player.stop() }
        engine.stop()
        isRunning = false
    }

    // MARK: Mixing

    public func apply(_ mix: AudioMixState, fade: TimeInterval = 0.25) {
        let master = mix.isMasterMuted ? 0 : mix.masterVolume
        for track in AudioTrack.allCases {
            let target = mix[track] * master
            channels[track]?.setVolume(target, fade: fade)
        }
    }

    public func setVolume(_ value: Float, for track: AudioTrack, fade: TimeInterval = 0.1) {
        channels[track]?.setVolume(value, fade: fade)
    }

    // MARK: Channel install

    private func installChannelsIfNeeded() throws {
        guard channels.isEmpty else { return }
        for track in AudioTrack.allCases {
            let player = AVAudioPlayerNode()
            let mixer = AVAudioMixerNode()
            engine.attach(player)
            engine.attach(mixer)
            engine.connect(player, to: mixer, format: format)
            engine.connect(mixer, to: mainMixer, format: format)
            mixer.outputVolume = 0
            let channel = Channel(track: track, player: player, mixer: mixer, format: format)
            channels[track] = channel
        }
    }
}

// MARK: - Channel

@MainActor
private final class Channel {

    let track: AudioTrack
    let player: AVAudioPlayerNode
    let mixer: AVAudioMixerNode
    let format: AVAudioFormat

    private var generator: SignalGenerator
    private var pendingBuffers: Int = 0
    private let queue = DispatchQueue(label: "syncspace.audio.\(UUID().uuidString)", qos: .userInteractive)

    init(track: AudioTrack, player: AVAudioPlayerNode, mixer: AVAudioMixerNode, format: AVAudioFormat) {
        self.track = track
        self.player = player
        self.mixer = mixer
        self.format = format
        self.generator = SignalGenerator(track: track, sampleRate: format.sampleRate)
    }

    func setVolume(_ value: Float, fade: TimeInterval) {
        let clamped = max(0, min(1, value))
        if fade <= 0 {
            mixer.outputVolume = clamped
            return
        }
        let steps = 12
        let interval = fade / Double(steps)
        let from = mixer.outputVolume
        for step in 1...steps {
            let progress = Float(step) / Float(steps)
            let next = from + (clamped - from) * progress
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(step)) { [weak self] in
                self?.mixer.outputVolume = next
            }
        }
    }

    func scheduleNextBufferIfNeeded() {
        while pendingBuffers < 2 {
            scheduleNextBuffer()
        }
    }

    private func scheduleNextBuffer() {
        let frames: AVAudioFrameCount = 22_050   // ~0.5s @ 44.1k
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
        buffer.frameLength = frames
        generator.render(into: buffer)
        pendingBuffers += 1
        player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.pendingBuffers -= 1
                self.scheduleNextBufferIfNeeded()
            }
        }
    }
}

// MARK: - Signal generation

private struct SignalGenerator {

    let track: AudioTrack
    let sampleRate: Double

    // Track-specific state
    private var pinkState = PinkNoise()
    private var brownState: Float = 0
    private var phase: Double = 0
    private var phase2: Double = 0
    private var phase3: Double = 0
    private var lpfState: Float = 0
    private var hpfState: Float = 0
    private var crackleTimer: Int = 0
    private var lofiTime: Double = 0
    private var rng: SystemRandomNumberGenerator = SystemRandomNumberGenerator()

    init(track: AudioTrack, sampleRate: Double) {
        self.track = track
        self.sampleRate = sampleRate
    }

    mutating func render(into buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData else { return }
        let channelCount = Int(buffer.format.channelCount)
        let frameCount = Int(buffer.frameLength)

        for frame in 0..<frameCount {
            let sample: Float
            switch track {
            case .rain:        sample = renderRainSample()
            case .whiteNoise:  sample = renderWhiteNoiseSample()
            case .cafe:        sample = renderCafeSample()
            case .forest:      sample = renderForestSample()
            case .lofi:        sample = renderLoFiSample()
            }
            for ch in 0..<channelCount {
                data[ch][frame] = sample
            }
        }
    }

    // MARK: Per-track renderers

    private mutating func renderRainSample() -> Float {
        // Pink noise filtered through a soft low-pass for steady rainfall,
        // plus occasional micro-impulses for distant drops.
        var s = pinkState.next() * 0.6
        // 1-pole low-pass.
        let alpha: Float = 0.18
        lpfState += alpha * (s - lpfState)
        s = lpfState
        if Int.random(in: 0..<2000) == 0 {
            s += Float.random(in: -0.4...0.4)
        }
        return s * 0.7
    }

    private mutating func renderWhiteNoiseSample() -> Float {
        Float.random(in: -1...1) * 0.4
    }

    private mutating func renderCafeSample() -> Float {
        // Brown noise base (low rumble) + pink chatter band-passed.
        let white = Float.random(in: -1...1)
        brownState = (brownState + 0.02 * white).clamped(to: -1...1)
        var rumble = brownState * 0.7
        let pink = pinkState.next()
        // High-pass the pink to emphasise mids (chatter).
        let hpfAlpha: Float = 0.06
        hpfState = hpfAlpha * (hpfState + pink - lpfState)
        lpfState = pink
        let chatter = hpfState * 0.5
        // Cup clink rare event.
        crackleTimer -= 1
        if crackleTimer <= 0, Int.random(in: 0..<8000) == 0 {
            rumble += Float.random(in: -0.2...0.2)
            crackleTimer = 200
        }
        return (rumble + chatter) * 0.6
    }

    private mutating func renderForestSample() -> Float {
        // Filtered pink (wind) + sparse bird chirps as gated sines.
        var wind = pinkState.next() * 0.5
        let alpha: Float = 0.10
        lpfState += alpha * (wind - lpfState)
        wind = lpfState
        // Wind gust modulation
        phase += 2 * .pi * 0.07 / sampleRate
        if phase > 2 * .pi { phase -= 2 * .pi }
        wind *= Float(0.6 + 0.4 * sin(phase))
        // Occasional bird-like chirp using a fast frequency sweep sine.
        var chirp: Float = 0
        if Int.random(in: 0..<24_000) == 0 { crackleTimer = 1200 }
        if crackleTimer > 0 {
            let t = Double(1200 - crackleTimer) / 1200.0
            let freq = 1800.0 + 600.0 * sin(t * 12)
            phase2 += 2 * .pi * freq / sampleRate
            chirp = Float(sin(phase2)) * Float(0.18 * (1 - t))
            crackleTimer -= 1
        }
        return (wind * 0.9 + chirp) * 0.7
    }

    private mutating func renderLoFiSample() -> Float {
        // Layered sines forming a warm minor-7 chord + slow LFO + tape hiss.
        lofiTime += 1.0 / sampleRate
        let fundamental: Double = 110.0   // A2
        let chord: [Double] = [1.0, 1.1892, 1.4983, 1.7818]  // ~root, m3, 5, m7
        var s: Double = 0
        for (i, ratio) in chord.enumerated() {
            phase = 2 * .pi * fundamental * ratio * lofiTime
            let detune = 1.0 + 0.0015 * sin(2 * .pi * 0.13 * lofiTime + Double(i))
            s += sin(phase * detune) * 0.18 * (1 - Double(i) * 0.15)
        }
        // Slow tremolo
        let trem = 0.85 + 0.15 * sin(2 * .pi * 0.25 * lofiTime)
        s *= trem
        // Tape hiss
        s += Double.random(in: -0.05...0.05)
        // Soft saturation
        let driven = tanh(s * 1.2)
        return Float(driven) * 0.55
    }
}

// MARK: - Pink noise (Paul Kellet's economy method)

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

// MARK: - utilities

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
