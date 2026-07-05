//
//  Glow.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

/// Convenience view modifiers that apply a soft colored shadow ("glow") behind a
/// view, used to draw attention to accent, positive, or negative elements (e.g. a
/// highlighted button or a profit/loss indicator) in the app's dark theme.
public extension View {
    /// Applies a soft glowing shadow in the brand accent color behind this view.
    /// - Parameter radius: The blur radius of the glow. Defaults to `12`.
    /// - Returns: The view with the glow shadow applied.
    func glowAccent(radius: CGFloat = 12) -> some View {
        self.shadow(color: DSColor.accent.opacity(0.55), radius: radius)
    }

    /// Applies a soft glowing shadow in the "positive" green behind this view,
    /// typically used to emphasize gains or upward price movement.
    /// - Parameter radius: The blur radius of the glow. Defaults to `12`.
    /// - Returns: The view with the glow shadow applied.
    func glowPositive(radius: CGFloat = 12) -> some View {
        self.shadow(color: DSColor.positive.opacity(0.55), radius: radius)
    }

    /// Applies a soft glowing shadow in the "negative" red behind this view,
    /// typically used to emphasize losses or downward price movement.
    /// - Parameter radius: The blur radius of the glow. Defaults to `12`.
    /// - Returns: The view with the glow shadow applied.
    func glowNegative(radius: CGFloat = 12) -> some View {
        self.shadow(color: DSColor.negative.opacity(0.55), radius: radius)
    }
}
