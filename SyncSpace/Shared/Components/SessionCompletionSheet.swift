//
//  SessionCompletionSheet.swift
//  SyncSpace
//
//  Modal celebration shown when a focus session reaches zero. The layout is
//  identical on Mac and iPhone — only the surrounding sheet behaviour
//  differs.
//

import SwiftUI

public struct SessionCompletionSheet: View {

    public let sessionType: SessionType
    public let onStartBreak: () -> Void
    public let onStartNewSession: () -> Void
    public let onDismiss: () -> Void

    public init(
        sessionType: SessionType,
        onStartBreak: @escaping () -> Void,
        onStartNewSession: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.sessionType = sessionType
        self.onStartBreak = onStartBreak
        self.onStartNewSession = onStartNewSession
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            badge

            VStack(spacing: DS.Spacing.xs) {
                Text("\(sessionType.title) complete")
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("Take a beat, then decide where to go next.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DS.Spacing.md)

            VStack(spacing: DS.Spacing.sm) {
                primary(title: "Start break (5 min)",
                        symbol: "leaf.fill",
                        action: onStartBreak)
                secondary(title: "Start \(sessionType.title.lowercased()) again",
                          symbol: "arrow.clockwise",
                          action: onStartNewSession)
                tertiary(title: "Dismiss", action: onDismiss)
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.top, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.lg)
        .frame(maxWidth: 460)
    }

    private var badge: some View {
        ZStack {
            Circle()
                .fill(AppTheme.sessionGradient)
                .frame(width: 92, height: 92)
                .shadow(color: AppTheme.electricIndigo.opacity(0.4), radius: 12, y: 4)
            Image(systemName: "checkmark")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func primary(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: symbol)
                Text(title)
            }
            .font(.callout.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md - 2)
            .background(AppTheme.sessionGradient, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.defaultAction)
    }

    @ViewBuilder
    private func secondary(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: symbol)
                Text(title)
            }
            .font(.callout.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md - 2)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
            )
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func tertiary(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
    }
}

// MARK: - Binding helper

public extension Binding where Value == Bool {
    /// Convenience for `.sheet(isPresented:)` bound to an optional source.
    static func optional<T>(_ source: Binding<T?>) -> Binding<Bool> {
        Binding<Bool>(
            get: { source.wrappedValue != nil },
            set: { isPresented in
                if !isPresented { source.wrappedValue = nil }
            }
        )
    }
}

#Preview {
    SessionCompletionSheet(
        sessionType: .focus,
        onStartBreak: {},
        onStartNewSession: {},
        onDismiss: {}
    )
    .background(.background)
}
