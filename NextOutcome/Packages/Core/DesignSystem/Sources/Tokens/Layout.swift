//
//  Layout.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

/// The app's centralized spacing and sizing scale ("design tokens"). Every layout
/// constant (margins, corner radii, spacing) should reference one of these instead
/// of hardcoding magic numbers, so the app's visual rhythm stays consistent and can
/// be tuned from one place.
public enum DSLayout {
    /// The standard horizontal screen margin (distance from screen edge to content).
    public static let margin: CGFloat = 16
    /// The corner radius used for card-style containers.
    public static let cardRadius: CGFloat = 16
    /// The corner radius used for fully-rounded pill-shaped elements (e.g. buttons,
    /// status badges).
    public static let pillRadius: CGFloat = 20
    /// The corner radius used for small chip elements (e.g. filter chips).
    public static let chipRadius: CGFloat = 10
    /// The smallest standard spacing unit, used between tightly related elements.
    public static let spacingXSmall: CGFloat = 6
    /// A small spacing unit, used between related elements that need slightly more room.
    public static let spacingSmall: CGFloat = 8
    /// A medium-small spacing unit.
    public static let spacingMedium: CGFloat = 10
    /// The standard spacing unit used between most stacked elements.
    public static let spacing: CGFloat = 12
    /// A larger spacing unit, used between distinct sections within a screen.
    public static let spacingLarge: CGFloat = 20
    /// The largest standard spacing unit, used between major sections of a screen.
    public static let spacingXLarge: CGFloat = 24
    /// The standard size for icon-sized square elements (e.g. avatar/logo thumbnails).
    public static let iconsize: CGFloat = 40
}
