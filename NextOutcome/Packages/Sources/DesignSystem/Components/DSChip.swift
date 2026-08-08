//
//  DSChip.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

/// A single tappable filter chip: a rounded pill button that shows an accent
/// gradient with a glow when active, or a plain surface background when inactive.
/// Used for filter rows (e.g. category/tag selectors) throughout the app.
public struct DSChip: View {
    /// The text shown on the chip.
    let label: String
    /// Whether this chip is the currently selected/active one, controlling its
    /// gradient background, glow, and text color.
    let isActive: Bool
    /// Called when the chip is tapped.
    let action: () -> Void

    /// Creates a chip.
    /// - Parameters:
    ///   - label: The text to display.
    ///   - isActive: Whether to render the active (highlighted) style.
    ///   - action: Called when the chip is tapped.
    public init(_ label: String, isActive: Bool, action: @escaping () -> Void) {
        self.label = label
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(label)
                .font(DSFont.caption.bold())
                .foregroundStyle(isActive ? .white : DSColor.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isActive ? AnyView(DSGradient.accent) : AnyView(DSColor.surface))
                .clipShape(Capsule())
                .glowAccent(radius: isActive ? 8 : 0)
        }
        .buttonStyle(.plain)
    }
}
