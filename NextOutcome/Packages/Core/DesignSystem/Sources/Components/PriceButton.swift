import SwiftUI

/// Tinted price button for trading rows: outcome name leading, cent price trailing.
/// `.yes`/`.no` tint green/red for binary markets; `.team` tints blue for sports rows.
public struct PriceButton: View {
    public enum Style {
        case yes
        case no
        case team
    }

    private let title: String
    private let price: String
    private let style: Style
    private let action: () -> Void

    public init(title: String, price: String, style: Style, action: @escaping () -> Void) {
        self.title = title
        self.price = price
        self.style = style
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DSLayout.spacingXSmall) {
                Text(title)
                    .font(DSFont.subheadline.bold())
                Spacer(minLength: DSLayout.spacingXSmall)
                Text(price)
                    .font(DSFont.priceSmall)
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, DSLayout.spacingMedium)
            .padding(.vertical, DSLayout.spacingSmall)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
        }
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        switch style {
        case .yes: DSColor.positive
        case .no: DSColor.negative
        case .team: DSColor.accent
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .yes: DSColor.positiveTint
        case .no: DSColor.negativeTint
        case .team: DSColor.accentTint
        }
    }
}
