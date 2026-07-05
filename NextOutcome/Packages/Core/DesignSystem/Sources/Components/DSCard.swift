//
//  DSCard.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

/// The app's standard rounded card container: padded content on a surface
/// background with a rounded border, optionally "highlighted" with an accent
/// tint. Used throughout the app to wrap market cards, event cards, and other
/// grouped content in a consistent visual container.
public struct DSCard<Content: View>: View {
    /// Whether to show the highlighted (accent-tinted background and border)
    /// style instead of the default surface style. Defaults to `false`.
    var highlighted: Bool
    /// The card's inner content.
    @ViewBuilder var content: () -> Content

    /// Creates a card.
    /// - Parameters:
    ///   - highlighted: Whether to use the accent-highlighted style. Defaults to `false`.
    ///   - content: A view builder producing the card's contents.
    public init(highlighted: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        self.highlighted = highlighted
        self.content = content
    }

    public var body: some View {
        content()
            .padding(DSLayout.margin)
            .background(
                highlighted ? DSColor.accentTint : DSColor.surface
            )
            .overlay(
                RoundedRectangle(cornerRadius: DSLayout.cardRadius)
                    .strokeBorder(highlighted ? DSColor.accent.opacity(0.3) : DSColor.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.cardRadius))
    }
}
