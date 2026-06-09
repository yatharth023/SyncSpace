//
//  RemoteMixerScreen.swift
//  SyncSpace
//
//  Remote audio mixer for iPhone. Interactive sliders send unreliable
//  updates so the Mac's audio engine tracks the gesture in real time.
//

#if os(iOS)
import SwiftUI

struct RemoteMixerScreen: View {
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                VStack(spacing: 14) {
                    ForEach(AudioTrack.allCases) { track in
                        TrackRow(
                            track: track,
                            level: model.mix[track],
                            pulse: model.pulse,
                            isMasterMuted: model.mix.isMasterMuted,
                            onChange: { model.setVolume($0, for: track) }
                        )
                    }
                }

                masterBus
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 48)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Ambient Mix")
                    .font(.title.weight(.bold))
                Spacer()
                ConnectionBadge(
                    status: model.peerManager.status,
                    peerNames: model.peerManager.connectedPeerNames,
                    compact: true
                )
            }
            Text("Drag to blend. The Mac's engine updates instantly.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var masterBus: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Master", systemImage: model.mix.isMasterMuted ? "speaker.slash.fill" : "speaker.wave.3.fill")
                    .font(.headline)
                Spacer()
                Button {
                    HapticManager.shared.trigger(.selection)
                    model.toggleMasterMute()
                } label: {
                    Text(model.mix.isMasterMuted ? "Unmute" : "Mute")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(model.mix.isMasterMuted ? AppTheme.error.opacity(0.3) : Color.white.opacity(0.1))
                        )
                        .overlay(
                            Capsule().stroke(model.mix.isMasterMuted ? AppTheme.error : .white.opacity(0.15), lineWidth: 1)
                        )
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { Double(model.mix.masterVolume) },
                    set: { model.setMasterVolume(Float($0)) }
                ), in: 0...1)
                .tint(AppTheme.accent)
                Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .glassCard()
    }
}

private struct TrackRow: View {
    let track: AudioTrack
    let level: Float
    let pulse: Double
    let isMasterMuted: Bool
    let onChange: (Float) -> Void

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(track.tint.opacity(0.25))
                    .frame(width: 56, height: 56)
                Image(systemName: track.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(track.tint)
                    .symbolEffect(.pulse.byLayer, options: .repeating, value: level > 0.05)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(track.title)
                            .font(.callout.weight(.semibold))
                        Text(track.subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    LevelMeter(level: isMasterMuted ? 0 : level, pulse: pulse, tint: track.tint, bars: 5)
                }
                Slider(value: Binding(
                    get: { Double(level) },
                    set: { onChange(Float($0)) }
                ), in: 0...1)
                .tint(track.tint)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 18)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(level > 0.01 ? track.tint.opacity(0.4) : .clear, lineWidth: 1)
        )
        .animation(.smooth(duration: 0.3), value: level > 0.01)
    }
}
#endif
