//
//  PageHeaderCapsule.swift
//  SyncSpace
//
//  Centred page-title pill shared by every screen. Owns its own typography,
//  padding, material, corner radius, and minimum width so individual screens
//  cannot drift out of lock-step. Designed to feel like Apple Music's section
//  pills and the native segmented controls: roomy horizontal padding, an
//  optically (not mathematically) centred glyph baseline, and a single hairline
//  for separation against the ambient backdrop.
//

import SwiftUI

public struct PageHeaderCapsule: View {

    public let title: String

    @Environment(\.colorScheme) private var scheme

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .tracking(0.2)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            // Asymmetric vertical padding pulls the cap-height onto the
            // geometric centre of the capsule. Without it the title floats
            // visually high — same trick UIKit uses inside segmented controls.
            .padding(.top, 12)
            .padding(.bottom, 11)
            .padding(.horizontal, 32)
            .frame(minWidth: 168)
            .background(DS.Surface.chip, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        Color.primary.opacity(scheme == .dark ? 0.10 : 0.08),
                        lineWidth: 1
                    )
            )
            .contentShape(Capsule(style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview("Light") {
    VStack(spacing: 18) {
        PageHeaderCapsule("Focus Session")
        PageHeaderCapsule("Tasks")
        PageHeaderCapsule("Audio Mixer")
        PageHeaderCapsule("Analytics")
        PageHeaderCapsule("Settings")
    }
    .padding(48)
    .preferredColorScheme(.light)
}

#Preview("Dark") {
    VStack(spacing: 18) {
        PageHeaderCapsule("Focus Session")
        PageHeaderCapsule("Tasks")
        PageHeaderCapsule("Audio Mixer")
        PageHeaderCapsule("Analytics")
        PageHeaderCapsule("Settings")
    }
    .padding(48)
    .preferredColorScheme(.dark)
}
