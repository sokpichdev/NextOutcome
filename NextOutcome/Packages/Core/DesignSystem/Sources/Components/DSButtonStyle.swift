//
//  DSButtonStyle.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

/// The shared body of the app's full-width action button styles: a raised pill that
/// presses down onto its lip, lit by a colored glow. The three styles below differ only
/// in colour and glow, so the layout lives here once.
///
/// The face is a **flat** fill, matching the sports moneyline `PriceButton`s. A vertical
/// gradient would shade the pill light-to-dark on its own, reading as a bevel on top of
/// the lip's depth — depth belongs to the lip alone.
private struct DSActionButtonBody<Glow: View>: View {
    /// The button's label, supplied by the `ButtonStyle`.
    let label: AnyView
    /// The flat fill painted on the pill's face.
    let face: Color
    /// The darker fill for the pill's lip.
    let lip: Color
    /// Whether the button is currently pressed.
    let isPressed: Bool
    /// Wraps the raised pill in the style's colored glow.
    let glow: (AnyView) -> Glow

    var body: some View {
        glow(
            AnyView(
                label
                    .font(DSFont.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .dsRaised(
                        face: face,
                        lip: lip,
                        cornerRadius: DSLayout.pillRadius,
                        depth: DSDepth.large,
                        isPressed: isPressed
                    )
            )
        )
    }
}

/// The app's standard full-width primary action button style: a raised accent-colored
/// pill with a glow that presses down when tapped. Use this via
/// `.buttonStyle(DSPrimaryButtonStyle())` for the main call-to-action on a screen
/// (e.g. "Continue", "Confirm").
public struct DSPrimaryButtonStyle: ButtonStyle {
    public init() {}
    /// Builds the styled button appearance from the button's label and press state.
    /// - Parameter configuration: Supplied by SwiftUI; contains the button's label
    ///   view and whether it's currently pressed.
    /// - Returns: The fully styled button view.
    public func makeBody(configuration: Configuration) -> some View {
        DSActionButtonBody(
            label: AnyView(configuration.label),
            face: DSColor.accent,
            lip: DSLip.accent,
            isPressed: configuration.isPressed,
            glow: { $0.glowAccent() }
        )
    }
}

/// A full-width button style for the "Buy Yes" trading action: a raised flat green
/// pill with a green glow. Use via `.buttonStyle(DSBuyYesButtonStyle())` on
/// the order ticket's "Yes" buy button.
public struct DSBuyYesButtonStyle: ButtonStyle {
    public init() {}
    /// Builds the styled button appearance from the button's label and press state.
    /// - Parameter configuration: Supplied by SwiftUI; contains the button's label
    ///   view and whether it's currently pressed.
    /// - Returns: The fully styled button view.
    public func makeBody(configuration: Configuration) -> some View {
        DSActionButtonBody(
            label: AnyView(configuration.label),
            face: DSColor.positive,
            lip: DSLip.positive,
            isPressed: configuration.isPressed,
            glow: { $0.glowPositive() }
        )
    }
}

/// A full-width button style for the "Buy No" trading action: a raised flat red
/// pill with a red glow. Use via `.buttonStyle(DSBuyNoButtonStyle())` on the order
/// ticket's "No" buy button.
public struct DSBuyNoButtonStyle: ButtonStyle {
    public init() {}
    /// Builds the styled button appearance from the button's label and press state.
    /// - Parameter configuration: Supplied by SwiftUI; contains the button's label
    ///   view and whether it's currently pressed.
    /// - Returns: The fully styled button view.
    public func makeBody(configuration: Configuration) -> some View {
        DSActionButtonBody(
            label: AnyView(configuration.label),
            face: DSColor.negative,
            lip: DSLip.negative,
            isPressed: configuration.isPressed,
            glow: { $0.glowNegative() }
        )
    }
}
