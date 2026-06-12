//
//  DesignSystem.swift
//  SyncSpace
//
//  Foundational design tokens. One place to change spacing, type, radii,
//  and animation curves so every screen stays in lock-step.
//

import SwiftUI

public enum DS {

    // MARK: Spacing scale (4 / 8 / 12 / 16 / 24 / 32 / 48)

    public enum Spacing {
        public static let xxs: CGFloat = 4
        public static let xs:  CGFloat = 8
        public static let sm:  CGFloat = 12
        public static let md:  CGFloat = 16
        public static let lg:  CGFloat = 24
        public static let xl:  CGFloat = 32
        public static let xxl: CGFloat = 48
    }

    // MARK: Corner radii

    public enum Radius {
        public static let pill: CGFloat = 999
        public static let xs:   CGFloat = 8
        public static let sm:   CGFloat = 12
        public static let md:   CGFloat = 16
        public static let lg:   CGFloat = 22
        public static let xl:   CGFloat = 28
    }

    // MARK: Animations (semantic, not arbitrary numbers)

    public enum Motion {
        /// Snappy spring used for transport buttons, taps, and primary actions.
        public static let snap = Animation.spring(response: 0.32, dampingFraction: 0.78)

        /// Smoother spring for screen transitions and large layout shifts.
        public static let glide = Animation.spring(response: 0.55, dampingFraction: 0.82)

        /// Calm fade for ambient elements (selection background, hover).
        public static let calm = Animation.easeInOut(duration: 0.22)

        /// For continuous value tracking (progress ring, faders).
        public static let track = Animation.easeOut(duration: 0.18)
    }

    // MARK: Materials

    public enum Surface {
        public static let card     = Material.regularMaterial
        public static let sidebar  = Material.thinMaterial
        public static let chip     = Material.ultraThinMaterial
    }
}

// MARK: - Typography

public extension Font {
    /// Display numeric (timer numerals).
    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Semantic colour helpers

public extension Color {
    /// Semantic background tint used behind hovered/selected rows in lists.
    static var rowHover: Color { Color.primary.opacity(0.06) }
    static var rowSelected: Color { Color.accentColor.opacity(0.16) }
}
