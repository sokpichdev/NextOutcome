//
//  Font+Tokens.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

/// The app's centralized typography scale ("design tokens"). Every text style in
/// the UI should reference one of these instead of building `Font` values inline,
/// so type sizes stay consistent and can be tuned app-wide from one place.
public enum DSFont {
    /// The largest text style, bolded. Used for prominent screen titles.
    public static let largeTitle = Font.largeTitle.bold()
    /// A bold title style, one size down from `largeTitle`. Used for section/page titles.
    public static let title = Font.title2.bold()
    /// A smaller, non-bold title style. Used for sub-section headers.
    public static let title3 = Font.title3
    /// Standard headline weight, used for emphasized row titles or card headers.
    public static let headline = Font.headline
    /// The default body text style, used for most regular text content.
    public static let body = Font.body
    /// A slightly smaller style than `body`, used for secondary descriptive text.
    public static let subheadline = Font.subheadline
    /// Small supporting text, used for metadata like timestamps or labels.
    public static let caption = Font.caption
    /// The smallest supporting text style, used for the least prominent labels.
    public static let caption2 = Font.caption2
    /// A bold, monospaced style sized for prominent price displays, so digits
    /// align evenly as prices change (monospaced digits don't shift width).
    public static let price = Font.system(.title2, design: .monospaced).bold()
    /// A smaller monospaced style for secondary/inline price values.
    public static let priceSmall = Font.system(.subheadline, design: .monospaced)
}
