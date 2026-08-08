//
//  Depth.swift
//  NextOutcome
//
//  Created by Sok Pich on 14/07/2026.
//

import SwiftUI

/// The app's centralized "3D"/tactile depth tokens. A raised element is drawn as a
/// coloured *face* sitting on top of a darker *lip* offset downwards, so it reads as
/// a physical key standing proud of the surface. Pressing translates the face down
/// onto the lip.
///
/// Every raised surface should take its geometry from here rather than hardcoding
/// offsets, so keys, pills, and action buttons all share one depth language.
public enum DSDepth {
    /// The lip height for small controls (keypad keys, chips).
    public static let small: CGFloat = 3
    /// The lip height for standard controls (Yes/No pills, price buttons).
    public static let medium: CGFloat = 4
    /// The lip height for prominent full-width actions (Trade / Buy Yes / Buy No).
    public static let large: CGFloat = 6

    /// How far the face travels when pressed, as a fraction of the lip height. Just
    /// short of 1 so a pressed key still reads as raised rather than collapsed.
    static let pressTravel: CGFloat = 0.8

    /// The spring the face rides on when pressed and released.
    static let pressAnimation: Animation = .spring(response: 0.16, dampingFraction: 0.7)
}

/// Renders a view as a raised, tactile surface: a flat filled face standing on a
/// darker lip, with a press animation that drives the face down onto it.
///
/// The depth lives entirely in the lip below the face — the face itself keeps the flat
/// fill it had before, no bevel or rim, so raised elements read as the app's existing
/// components lifted off the surface rather than as a different visual language.
///
/// Apply via `View.dsRaised(...)` rather than constructing this directly.
private struct DSRaisedSurface: ViewModifier {
    /// The fill painted on the face of the key.
    let face: AnyShapeStyle
    /// The fill painted on the lip beneath the face — normally a darker shade of `face`.
    let lip: AnyShapeStyle
    /// Corner radius shared by the face and the lip.
    let cornerRadius: CGFloat
    /// How tall the lip is; also how far the face travels when pressed.
    let depth: CGFloat
    /// Whether the face is currently pressed down onto the lip.
    let isPressed: Bool

    /// The face's vertical travel for the current press state.
    private var travel: CGFloat { isPressed ? depth * DSDepth.pressTravel : 0 }

    /// The shape used for both the face and the lip.
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }

    /// The lip, as only the crescent left uncovered by the face — the full shape dropped
    /// by `depth` with the face's current footprint subtracted out.
    ///
    /// Subtracting matters because faces are often *translucent* (a `DSColor` tint pill).
    /// Drawing a full lip behind one would show the darker lip straight through the face
    /// and muddy its colour; this way a translucent face still reveals the card behind it.
    private var lipShape: some Shape {
        shape.offset(y: depth).subtracting(shape.offset(y: travel))
    }

    func body(content: Content) -> some View {
        content
            // The label rides the face down when pressed.
            .offset(y: travel)
            // The face — flat, exactly the fill the element had before it was raised.
            .background {
                shape
                    .fill(face)
                    .offset(y: travel)
            }
            // The lip, which stays put while the face travels onto it.
            .background {
                lipShape.fill(lip)
            }
            // Reserve the lip's height in layout so raised elements don't overlap.
            .padding(.bottom, depth)
            .contentShape(shape)
            .animation(DSDepth.pressAnimation, value: isPressed)
    }
}

public extension View {
    /// Renders this view as a raised 3D surface — a filled face standing on a darker
    /// lip — that presses down when `isPressed` is true.
    ///
    /// The lip's height is reserved in layout, so a raised view is `depth` points
    /// taller than its content.
    /// - Parameters:
    ///   - face: The fill for the top face of the surface.
    ///   - lip: The fill for the lip beneath it — normally a darker shade of `face`.
    ///   - cornerRadius: The corner radius for the face and lip. Defaults to `DSLayout.chipRadius`.
    ///   - depth: The lip height. Defaults to `DSDepth.medium`.
    ///   - isPressed: Whether the surface is pressed down onto its lip.
    /// - Returns: The view rendered as a raised surface.
    func dsRaised<Face: ShapeStyle, Lip: ShapeStyle>(
        face: Face,
        lip: Lip,
        cornerRadius: CGFloat = DSLayout.chipRadius,
        depth: CGFloat = DSDepth.medium,
        isPressed: Bool = false
    ) -> some View {
        modifier(
            DSRaisedSurface(
                face: AnyShapeStyle(face),
                lip: AnyShapeStyle(lip),
                cornerRadius: cornerRadius,
                depth: depth,
                isPressed: isPressed
            )
        )
    }
}

/// A `ButtonStyle` that renders its label as a raised 3D surface which presses down
/// on tap. Use via `.buttonStyle(DSRaisedButtonStyle(face:lip:))` for any tappable
/// element that should feel like a physical key.
public struct DSRaisedButtonStyle: ButtonStyle {
    /// The fill for the top face of the key.
    private let face: AnyShapeStyle
    /// The fill for the lip beneath the face.
    private let lip: AnyShapeStyle
    /// The corner radius for the key.
    private let cornerRadius: CGFloat
    /// The lip height.
    private let depth: CGFloat

    /// Creates a raised button style.
    /// - Parameters:
    ///   - face: The fill for the top face of the key.
    ///   - lip: The fill for the lip beneath it — normally a darker shade of `face`.
    ///   - cornerRadius: The corner radius. Defaults to `DSLayout.chipRadius`.
    ///   - depth: The lip height. Defaults to `DSDepth.medium`.
    public init<Face: ShapeStyle, Lip: ShapeStyle>(
        face: Face,
        lip: Lip,
        cornerRadius: CGFloat = DSLayout.chipRadius,
        depth: CGFloat = DSDepth.medium
    ) {
        self.face = AnyShapeStyle(face)
        self.lip = AnyShapeStyle(lip)
        self.cornerRadius = cornerRadius
        self.depth = depth
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .dsRaised(
                face: face,
                lip: lip,
                cornerRadius: cornerRadius,
                depth: depth,
                isPressed: configuration.isPressed
            )
    }
}

/// Darker "lip" fills that pair with the palette's face colours. A lip is the shadowed
/// side wall of a raised key, so it's the face colour with the light taken out of it.
public enum DSLip {
    /// The lip under an accent-blue face.
    public static let accent = DSColor.accent2.dsDarkened(0.30)
    /// The lip under a positive/green face.
    public static let positive = DSColor.positive2.dsDarkened(0.30)
    /// The lip under a negative/red face.
    public static let negative = DSColor.negative2.dsDarkened(0.30)
    /// The lip under a neutral elevated-surface face (keypad keys, quick-add chips).
    public static let surface = DSColor.surfaceElevated.dsDarkened(0.22)
    /// The lip under a translucent tint face (an unselected Yes/No pill).
    /// - Parameter tint: The tint painted on the face.
    /// - Returns: The matching lip fill.
    public static func tint(_ tint: Color) -> Color { tint.dsDarkened(0.35) }
}

extension Color {
    /// Returns this colour composited over black at `amount` strength — i.e. the same
    /// hue with the light taken out, which is what a shadowed side wall looks like.
    /// - Parameter amount: How far to darken, 0 (unchanged) to 1 (black).
    func dsDarkened(_ amount: Double) -> Color {
        dsBlended(with: .black, amount: amount)
    }

    /// Blends this colour towards `other` by `amount`, resolving both against the
    /// active appearance so dynamic tokens keep their light/dark behaviour.
    /// - Parameters:
    ///   - other: The colour to blend towards.
    ///   - amount: How far to blend, 0 (unchanged) to 1 (fully `other`).
    func dsBlended(with other: Color, amount: Double) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { traits in
            let base = UIColor(self).resolvedColor(with: traits)
            let target = UIColor(other).resolvedColor(with: traits)
            var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
            var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
            base.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            target.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            let t = CGFloat(amount)
            return UIColor(
                red:   r1 + (r2 - r1) * t,
                green: g1 + (g2 - g1) * t,
                blue:  b1 + (b2 - b1) * t,
                alpha: a1 + (a2 - a1) * t
            )
        })
        #else
        return self
        #endif
    }
}
