//
//  Gradients.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

/// The app's centralized gradient palette ("design tokens"), built from `DSColor`
/// values. Used for buttons, chart fills, and highlighted backgrounds so gradients
/// stay consistent across the app.
public enum DSGradient {
    /// A diagonal blue gradient (brand accent), typically used for primary buttons
    /// and highlighted UI elements.
    public static let accent = LinearGradient(
        colors: [DSColor.accent, DSColor.accent2],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    /// A diagonal green gradient, typically used for "buy"/positive actions or
    /// profit indicators.
    public static let positive = LinearGradient(
        colors: [DSColor.positive, DSColor.positive2],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    /// A diagonal red gradient, typically used for "sell"/negative actions or
    /// loss indicators.
    public static let negative = LinearGradient(
        colors: [DSColor.negative, DSColor.negative2],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    /// A top-to-bottom fade from translucent green to fully transparent. Used to
    /// fill the area under a positive price chart line.
    public static let positiveArea = LinearGradient(
        colors: [DSColor.positive.opacity(0.35), DSColor.positive.opacity(0)],
        startPoint: .top, endPoint: .bottom
    )
    /// A top-to-bottom fade from translucent accent blue to fully transparent.
    /// Used to fill the area under a neutral/accent-colored chart line.
    public static let accentArea = LinearGradient(
        colors: [DSColor.accent.opacity(0.35), DSColor.accent.opacity(0)],
        startPoint: .top, endPoint: .bottom
    )
}
