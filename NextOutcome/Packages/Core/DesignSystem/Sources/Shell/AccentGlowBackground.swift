import SwiftUI

/// Standard root background: near-black base with a soft radial accent glow behind the top bar.
public struct AccentGlowBackground<Content: View>: View {
    private let content: Content
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
