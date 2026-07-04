//
//  DSButtonStyle.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

/// The app's standard full-width primary action button style: an accent-colored
/// gradient pill with a glow and a pressed-state dimming effect. Use this via
/// `.buttonStyle(DSPrimaryButtonStyle())` for the main call-to-action on a screen
/// (e.g. "Continue", "Confirm").
public struct DSPrimaryButtonStyle: ButtonStyle {
    public init() {}
    /// Builds the styled button appearance from the button's label and press state.
    /// - Parameter configuration: Supplied by SwiftUI; contains the button's label
    ///   view and whether it's currently pressed.
    /// - Returns: The fully styled button view.
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFont.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(DSGradient.accent)
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.pillRadius))
            .glowAccent()
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// A full-width button style for the "Buy Yes" trading action: a green gradient
/// pill with a green glow. Use via `.buttonStyle(DSBuyYesButtonStyle())` on the
/// order ticket's "Yes" buy button.
public struct DSBuyYesButtonStyle: ButtonStyle {
    public init() {}
    /// Builds the styled button appearance from the button's label and press state.
    /// - Parameter configuration: Supplied by SwiftUI; contains the button's label
    ///   view and whether it's currently pressed.
    /// - Returns: The fully styled button view.
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFont.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(DSGradient.positive)
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.pillRadius))
            .glowPositive()
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// A full-width button style for the "Buy No" trading action: a red gradient pill
/// with a red glow. Use via `.buttonStyle(DSBuyNoButtonStyle())` on the order
/// ticket's "No" buy button.
public struct DSBuyNoButtonStyle: ButtonStyle {
    public init() {}
    /// Builds the styled button appearance from the button's label and press state.
    /// - Parameter configuration: Supplied by SwiftUI; contains the button's label
    ///   view and whether it's currently pressed.
    /// - Returns: The fully styled button view.
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFont.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(DSGradient.negative)
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.pillRadius))
            .glowNegative()
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
