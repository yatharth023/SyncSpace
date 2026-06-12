//
//  ViewModifiers.swift
//  SyncSpace
//
//  Reusable visual treatments. Theme-aware so cards adapt to light/dark.
//

import SwiftUI

/// Adaptive glass card that works in both colour schemes. Avoids the heavy
/// black-only treatment of the previous implementation.
public struct GlassCardStyle: ViewModifier {
    public var cornerRadius: CGFloat = DS.Radius.lg

    @Environment(\.colorScheme) private var scheme

    public func body(content: Content) -> some View {
        // Apple Music / Things 3 style cards rely on the material background
        // and a 1px hairline border for separation; no shadow. Drop shadows
        // are an offscreen-blur pass per card and were the dominant cost
        // during scrolling.
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DS.Surface.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        Color.primary.opacity(scheme == .dark ? 0.10 : 0.07),
                        lineWidth: 1
                    )
            )
    }
}

/// Lightweight section header used on every screen. Generous padding,
/// proper hierarchy (large title + supportive caption).
public struct ScreenHeader: View {
    public let title: String
    public let subtitle: String?
    public let symbol: String?
    public let trailing: AnyView?

    public init(
        title: String,
        subtitle: String? = nil,
        symbol: String? = nil,
        trailing: AnyView? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.trailing = trailing
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                HStack(spacing: DS.Spacing.xs) {
                    if let symbol {
                        Image(systemName: symbol)
                            .font(.title3)
                            .foregroundStyle(AppTheme.accent)
                    }
                    Text(title)
                        .font(.system(.largeTitle, design: .default, weight: .bold))
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if let trailing {
                trailing
            }
        }
        .padding(.bottom, DS.Spacing.xs)
        .accessibilityElement(children: .combine)
    }
}

/// Chip-style label used for status / metadata. Generous padding so the text
/// doesn't crowd the capsule.
public struct InfoChip: View {
    public let title: String
    public let symbol: String?
    public var tint: Color = AppTheme.accent

    public init(title: String, symbol: String? = nil, tint: Color = AppTheme.accent) {
        self.title = title
        self.symbol = symbol
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs + 2)
        .background(DS.Surface.chip, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

public extension View {
    func glassCard(cornerRadius: CGFloat = DS.Radius.lg) -> some View {
        modifier(GlassCardStyle(cornerRadius: cornerRadius))
    }
}
