import SwiftUI

/// Tinted, raised price button for trading rows: outcome name leading, cent price
/// trailing. Every style renders as a 3D key that presses down onto its lip when
/// tapped — the same depth language as the trade sheet's keypad.
/// `.yes`/`.no` tint green/red for binary markets; `.team` tints blue for sports rows.
/// `.solid` fills with a team's brand colour (white text); `.neutral` is the draw slot.
public struct PriceButton: View {
    /// Which visual treatment to apply, based on what kind of outcome this button represents.
    public enum Style {
        /// The green-tinted "Yes" side of a binary market.
        case yes
        /// The red-tinted "No" side of a binary market.
        case no
        /// A blue-tinted generic team pick (used before a specific brand color is known).
        case team
        /// Solid fill in the given colour with white text — a sports moneyline pick.
        case solid(Color)
        /// Neutral filled slot (the "Draw" outcome).
        case neutral
    }

    /// The outcome label shown on the leading side (e.g. "Yes", a team name).
    private let title: String
    /// The formatted price shown on the trailing (or centered) side, e.g. "62¢".
    private let price: String
    /// Which visual style to render.
    private let style: Style
    /// Called when the button is tapped.
    private let action: () -> Void
    /// Bumped on each tap to drive `.sensoryFeedback`, which fires on change.
    @State private var pressTick = 0

    /// Creates a price button.
    /// - Parameters:
    ///   - title: The outcome label to display.
    ///   - price: The formatted price to display.
    ///   - style: The visual style to use.
    ///   - action: Called when tapped.
    public init(title: String, price: String, style: Style, action: @escaping () -> Void) {
        self.title = title
        self.price = price
        self.style = style
        self.action = action
    }

    public var body: some View {
        Button {
            pressTick &+= 1
            action()
        } label: {
            content
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, DSLayout.spacingMedium)
                .padding(.vertical, DSLayout.spacingSmall)
        }
        .buttonStyle(
            DSRaisedButtonStyle(
                face: backgroundColor,
                lip: lipColor,
                depth: DSDepth.medium
            )
        )
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: pressTick)
    }

    /// The button's inner layout. `.solid`/`.neutral` styles (used for sports
    /// moneyline rows with three equal-width buttons) center the title and price
    /// together; other styles put the title leading and price trailing.
    @ViewBuilder
    private var content: some View {
        switch style {
        case .solid, .neutral:
            // Centred "COL 18¢" — matches the sports card's equal-thirds buttons.
            HStack(spacing: DSLayout.spacingXSmall) {
                Text(title).font(DSFont.caption.bold())
                Text(price).font(DSFont.priceSmall.bold())
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
        default:
            HStack(spacing: DSLayout.spacingXSmall) {
                Text(title).font(DSFont.subheadline.bold())
                Spacer(minLength: DSLayout.spacingXSmall)
                Text(price).font(DSFont.priceSmall)
            }
        }
    }

    /// The text/icon color to use for the current `style`.
    private var foregroundColor: Color {
        switch style {
        case .yes: DSColor.positive
        case .no: DSColor.negative
        case .team: DSColor.accent
        case .solid: .white
        case .neutral: DSColor.textPrimary
        }
    }

    /// The background fill color to use for the current `style`.
    private var backgroundColor: Color {
        switch style {
        case .yes: DSColor.positiveTint
        case .no: DSColor.negativeTint
        case .team: DSColor.accentTint
        case .solid(let color): color
        case .neutral: DSColor.surfaceElevated
        }
    }

    /// The lip (side-wall) color beneath the face for the current `style` — the face
    /// colour with the light taken out of it.
    private var lipColor: Color {
        switch style {
        case .yes: DSLip.tint(DSColor.positiveTint)
        case .no: DSLip.tint(DSColor.negativeTint)
        case .team: DSLip.tint(DSColor.accentTint)
        case .solid(let color): color.dsDarkened(0.35)
        case .neutral: DSLip.surface
        }
    }
}
