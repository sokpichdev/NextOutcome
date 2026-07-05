import SwiftUI
import DesignSystem

/// Compact header overlaid once the user scrolls past the chart: abbreviated
/// outcome labels, the leading chance %, and a "Trade" button shortcutting to
/// the top market.
public struct StickyEventHeader: View {
    /// The left/home side's abbreviation.
    private let leftAbbrev: String
    /// The right/away side's abbreviation.
    private let rightAbbrev: String
    /// The leading chance percentage text.
    private let chanceText: String
    /// Called when the "Trade" shortcut is tapped.
    private let onTrade: () -> Void

    /// Creates the sticky header.
    /// - Parameters:
    ///   - leftAbbrev: Left side abbreviation.
    ///   - rightAbbrev: Right side abbreviation.
    ///   - chanceText: The chance percentage text.
    ///   - onTrade: Action for the Trade button.
    public init(leftAbbrev: String, rightAbbrev: String, chanceText: String, onTrade: @escaping () -> Void) {
        self.leftAbbrev = leftAbbrev
        self.rightAbbrev = rightAbbrev
        self.chanceText = chanceText
        self.onTrade = onTrade
    }

    public var body: some View {
        HStack(spacing: DSLayout.spacing) {
            Text("\(leftAbbrev) vs \(rightAbbrev)")
                .font(DSFont.subheadline.bold())
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(1)
            Text(chanceText)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
            Spacer()
            Button(action: onTrade) {
                Text("Trade")
                    .font(DSFont.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, DSLayout.spacingMedium)
                    .padding(.vertical, DSLayout.spacingSmall)
                    .background(DSGradient.accent)
                    .clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DSLayout.margin)
        .padding(.vertical, DSLayout.spacingSmall)
        .background(DSColor.background)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DSColor.separator).frame(height: 1)
        }
    }
}

#if DEBUG
#Preview("Sticky event header") {
    VStack {
        StickyEventHeader(leftAbbrev: "ARG", rightAbbrev: "CVI", chanceText: "86%", onTrade: {})
        Spacer()
    }
    .background(DSColor.background)
}
#endif
