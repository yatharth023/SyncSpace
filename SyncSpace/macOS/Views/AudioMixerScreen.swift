//
//  AudioMixerScreen.swift
//  SyncSpace
//
//  Professional ambient mixer. Each track has a level meter, vertical
//  fader, mute toggle, and tint. Changes broadcast to iPhone in real time.
//

#if os(macOS)
import SwiftUI

struct AudioMixerScreen: View {
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                channelStrip
                masterBus
            }
            .padding(36)
            .frame(maxWidth: 980)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            model.audioEngine?.start()
            model.audioEngine?.apply(model.mix, fade: 0)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ambient Mixer")
                .font(.largeTitle.weight(.bold))
            Text("Blend layered soundscapes. Each fader drives a procedurally-generated channel and mirrors instantly on iPhone.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: 680, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var channelStrip: some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(AudioTrack.allCases) { track in
                MixerChannel(
                    track: track,
                    level: model.mix[track],
                    pulse: model.pulse,
                    isMasterMuted: model.mix.isMasterMuted,
                    onChange: { value in
                        model.setVolume(value, for: track)
                    },
                    onToggleMute: {
                        let isCurrentlyAudible = model.mix[track] > 0.01
                        model.setVolume(isCurrentlyAudible ? 0 : 0.6, for: track)
                    }
                )
            }
        }
    }

    private var masterBus: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Master Bus", systemImage: "speaker.wave.3.fill")
                    .font(.headline)
                Text("Global volume and quick mute")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            HStack(spacing: 12) {
                Image(systemName: "speaker.fill")
                    .foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { Double(model.mix.masterVolume) },
                    set: { model.setMasterVolume(Float($0)) }
                ), in: 0...1)
                .tint(AppTheme.accent)
                .frame(width: 260)
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundStyle(.secondary)
            }

            Button {
                model.toggleMasterMute()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: model.mix.isMasterMuted ? "speaker.slash.fill" : "speaker.wave.3.fill")
                    Text(model.mix.isMasterMuted ? "Muted" : "Mute")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(model.mix.isMasterMuted ? AppTheme.error.opacity(0.3) : Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(model.mix.isMasterMuted ? AppTheme.error : .white.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .glassCard()
    }
}

private struct MixerChannel: View {
    let track: AudioTrack
    let level: Float
    let pulse: Double
    let isMasterMuted: Bool
    let onChange: (Float) -> Void
    let onToggleMute: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            // Icon header
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(track.tint.opacity(0.25))
                    .frame(height: 70)
                Image(systemName: track.symbol)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 28))
                    .foregroundStyle(track.tint)
                    .symbolEffect(.pulse.byLayer, options: .repeating, value: level > 0.05)
            }

            Text(track.title)
                .font(.callout.weight(.semibold))
            Text(track.subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)

            // Level meter
            LevelMeter(
                level: isMasterMuted ? 0 : level,
                pulse: pulse,
                tint: track.tint
            )
            .frame(height: 60)

            // Vertical fader
            VerticalFader(
                value: Binding(
                    get: { Double(level) },
                    set: { onChange(Float($0)) }
                ),
                tint: track.tint
            )
            .frame(height: 160)

            Text("\(Int(level * 100))")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(level > 0.01 ? .white : .secondary)

            Button(action: onToggleMute) {
                Image(systemName: level > 0.01 ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .foregroundStyle(level > 0.01 ? .white : .secondary)
                    .padding(8)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(minWidth: 140)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
                .stroke(level > 0.01 ? track.tint.opacity(0.4) : .clear, lineWidth: 1)
        )
        .animation(.smooth(duration: 0.3), value: level > 0.01)
    }
}

private struct VerticalFader: View {
    @Binding var value: Double
    var tint: Color

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            let position = CGFloat(1 - value) * height
            ZStack(alignment: .bottom) {
                // Track
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 6)
                    .frame(maxHeight: .infinity)
                // Filled portion
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 6, height: CGFloat(value) * height)
                    .animation(.smooth(duration: 0.1), value: value)
                // Knob
                Circle()
                    .fill(.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: tint.opacity(0.7), radius: 6)
                    .overlay(
                        Circle().stroke(tint, lineWidth: 2)
                    )
                    .position(x: proxy.size.width / 2, y: position)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let raw = 1 - (gesture.location.y / height)
                        let clamped = max(0, min(1, Double(raw)))
                        value = clamped
                    }
            )
        }
        .frame(width: 44)
    }
}
#endif
