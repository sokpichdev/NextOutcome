import SwiftUI

/// Standard root background: near-black base with a soft radial accent glow behind the top bar.
///
/// Wrap any top-level screen's content in this to get the app's consistent dark
/// background treatment — a solid near-black base plus a subtle blue glow
/// emanating from the top of the screen, used throughout the app for visual
/// consistency behind the top bar/navigation area.
///
/// Usage:
/// ```swift
/// AccentGlowBackground {
///     MyScreenContent()
/// }
/// ```
public struct AccentGlowBackground<Content: View>: View {
    /// The screen content to render on top of the glowing background.
    private let content: Content

    /// Creates the background wrapper around the given content.
    /// - Parameter content: A view builder producing the content to display on
    ///   top of the background.
    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        ZStack(alignment: .top) {
            DSColor.background.ignoresSafeArea()
            RadialGradient(
                colors: [DSColor.accent.opacity(0.18), .clear],
                center: .top, startRadius: 0, endRadius: 320
            )
            .ignoresSafeArea()
            content
        }
    }
}
