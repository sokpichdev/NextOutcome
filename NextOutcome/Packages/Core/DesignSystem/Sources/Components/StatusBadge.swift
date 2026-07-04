//
//  StatusBadge.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

/// A small pill-shaped label used to show a short status word (e.g. "LIVE",
/// "CLOSED", "RESOLVED") in a given color, with a tinted translucent background
/// matching the text color.
public struct StatusBadge: View {
    /// The short label text to display, typically all-caps (e.g. "LIVE").
    let text: String
    /// The color used for both the text and (at reduced opacity) the background pill.
    let color: Color

    /// Creates a status badge.
    /// - Parameters:
    ///   - text: The label to display.
    ///   - color: The color to use for the text and tinted background.
    public init(_ text: String, color: Color) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .font(DSFont.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}
