//
//  AudioMixerScreen.swift
//  SyncSpace
//
//  Mac mixer. Bindings write straight into AppModel.setVolume which writes
//  directly to AVAudioMixerNode.outputVolume — no fades, no schedulers, no
//  buffer thrashing. Slider drags are now glitch-free.
//

#if os(macOS)
import SwiftUI

struct AudioMixerScreen: View {
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                ScreenHeader(
                    title: "Audio Mixer",
                    subtitle: "Blend layered ambient soundscapes. Each fader drives a continuous channel and mirrors instantly on iPhone."
                )

                channelStrip
                masterBus
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xxl)
            .frame(maxWidth: 1000)
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            model.audioEngine?.start()
            model.audioEngine?.apply(model.mix)
        }
    }

    private var channelStrip: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            ForEach(AudioTrack.allCases) { track in
                MixerChannel(
                    track: track,
                    level: model.mix[track],
                    isMasterMuted: model.mix.isMasterMuted,
                    onChange: { value in model.setVolume(value, for: track) },
                    onToggleMute: {
                        let audible = model.mix[track] > 0.01
                        model.setVolume(audible ? 0 : 0.6, for: track)
                    }
                )
            }
        }
    }

    private var masterBus: some View {
        HStack(spacing: DS.Spacing.lg) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Label("Master Bus", systemImage: "speaker.wave.3.fill")
                    .font(.headline)
                Text("Global volume and mute")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { Double(model.mix.masterVolume) },
                    set: { model.setMasterVolume(Float($0)) }
                ), in: 0...1)
                .tint(AppTheme.accent)
                .frame(width: 240)
                Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
            }
            Button {
                model.toggleMasterMute()
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: model.mix.isMasterMuted ? "speaker.slash.fill" : "speaker.wave.3.fill")
                    Text(model.mix.isMasterMuted ? "Muted" : "Mute")
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        .fill(model.mix.isMasterMuted ? AppTheme.error.opacity(0.22) : Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        .strokeBorder(model.mix.isMasterMuted ? AppTheme.error : Color.primary.opacity(0.10), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Spacing.lg)
        .glassCard()
    }
}

// MARK: - Mixer channel

private struct MixerChannel: View {
    let track: AudioTrack
    let level: Float
    let isMasterMuted: Bool
    let onChange: (Float) -> Void
    let onToggleMute: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(track.tint.opacity(0.20))
                    .frame(height: 64)
                Image(systemName: track.symbol)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 26))
                    .foregroundStyle(track.tint)
                    .symbolEffect(.pulse.byLayer, options: .repeating, isActive: level > 0.05)
            }

            VStack(spacing: 2) {
                Text(track.title).font(.callout.weight(.semibold))
                Text(track.subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }

            LevelMeter(level: isMasterMuted ? 0 : level, tint: track.tint)
                .frame(height: 52)

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
                .foregroundStyle(level > 0.01 ? .primary : .secondary)

            Button(action: onToggleMute) {
                Image(systemName: level > 0.01 ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .foregroundStyle(level > 0.01 ? .primary : .secondary)
                    .padding(DS.Spacing.xs)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, DS.Spacing.lg - 4)
        .padding(.horizontal, DS.Spacing.md)
        .frame(minWidth: 140)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(level > 0.01 ? track.tint.opacity(0.40) : .clear, lineWidth: 1)
        )
        .animation(DS.Motion.calm, value: level > 0.01)
    }
}

// MARK: - Vertical fader

private struct VerticalFader: View {
    @Binding var value: Double
    var tint: Color

    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            let position = CGFloat(1 - value) * h
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(Color.primary.opacity(0.10))
                    .frame(width: 6)
                    .frame(maxHeight: .infinity)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 6, height: CGFloat(value) * h)
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: tint.opacity(0.55), radius: 6)
                    .overlay(Circle().strokeBorder(tint, lineWidth: 2))
                    .position(x: proxy.size.width / 2, y: position)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let raw = 1 - (g.location.y / h)
                        value = max(0, min(1, Double(raw)))
                    }
            )
        }
        .frame(width: 44)
    }
}
#endif
