//
//  RemoteMixerScreen.swift
//  SyncSpace
//

#if os(iOS)
import SwiftUI

struct RemoteMixerScreen: View {
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.md) {
                ScreenHeader(
                    title: "Ambient Mix",
                    subtitle: "Drag to blend. The Mac's engine updates instantly.",
                    trailing: AnyView(
                        ConnectionBadge(
                            status: model.peerManager.status,
                            peerNames: model.peerManager.connectedPeerNames,
                            compact: true
                        )
                    )
                )

                VStack(spacing: DS.Spacing.sm) {
                    ForEach(AudioTrack.allCases) { track in
                        TrackRow(
                            track: track,
                            level: model.mix[track],
                            isMasterMuted: model.mix.isMasterMuted,
                            onChange: { model.setVolume($0, for: track) }
                        )
                    }
                }

                masterBus
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .scrollIndicators(.hidden)
    }

    private var masterBus: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
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
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(
                            Capsule().fill(model.mix.isMasterMuted ? AppTheme.error.opacity(0.22) : Color.primary.opacity(0.08))
                        )
                        .overlay(
                            Capsule().strokeBorder(model.mix.isMasterMuted ? AppTheme.error : Color.primary.opacity(0.12), lineWidth: 1)
                        )
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                Slider(value: Binding(
                    get: { Double(model.mix.masterVolume) },
                    set: { model.setMasterVolume(Float($0)) }
                ), in: 0...1)
                .tint(AppTheme.accent)
                Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
            }
        }
        .padding(DS.Spacing.lg)
        .glassCard()
    }
}

private struct TrackRow: View {
    let track: AudioTrack
    let level: Float
    let isMasterMuted: Bool
    let onChange: (Float) -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(track.tint.opacity(0.22))
                    .frame(width: 52, height: 52)
                Image(systemName: track.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(track.tint)
                    .symbolEffect(.pulse.byLayer, options: .repeating, isActive: level > 0.05)
            }
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(track.title).font(.callout.weight(.semibold))
                        Text(track.subtitle).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    LevelMeter(level: isMasterMuted ? 0 : level, tint: track.tint, bars: 5)
                }
                Slider(value: Binding(
                    get: { Double(level) },
                    set: { onChange(Float($0)) }
                ), in: 0...1)
                .tint(track.tint)
            }
        }
        .padding(DS.Spacing.md)
        .glassCard(cornerRadius: DS.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(level > 0.01 ? track.tint.opacity(0.40) : .clear, lineWidth: 1)
        )
        .animation(DS.Motion.calm, value: level > 0.01)
    }
}
#endif
