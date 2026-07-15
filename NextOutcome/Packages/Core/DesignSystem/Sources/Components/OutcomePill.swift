//
//  OutcomePill.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

/// A pill showing a binary market outcome ("Yes"/"No") alongside its price/value,
/// colored green for "Yes" and red for "No". Used on market cards and trade
/// buttons to show current pricing for each side of a binary market.
public struct OutcomePill: View {
    /// The two sides of a binary (yes/no) market outcome.
    public enum Outcome {
        /// The "Yes" side, rendered in green.
        case yes
        /// The "No" side, rendered in red.
        case no
    }
    /// Which side of the outcome this pill represents.
    let outcome: Outcome
    /// The value to display alongside the outcome label, typically a formatted
    /// price or probability (e.g. "62¢"). `nil` shows just the "Yes"/"No" label.
    let value: String?

    /// Creates an outcome pill.
    /// - Parameters:
    ///   - outcome: Whether this is the "Yes" or "No" side.
    ///   - value: The formatted price/value string to display alongside the label, or `nil`
    ///     to show just "Yes"/"No" (e.g. when the price is already shown elsewhere on the row).
    public init(_ outcome: Outcome, value: String? = nil) {
        self.outcome = outcome
        self.value = value
    }

    /// The translucent tint painted on the pill's face.
    private var tint: Color { outcome == .yes ? DSColor.positiveTint : DSColor.negativeTint }

    public var body: some View {
        HStack(spacing: 4) {
            Text(outcome == .yes ? "Yes" : "No")
                .font(DSFont.caption.bold())
            if let value {
                Text(value)
                    .font(DSFont.priceSmall)
            }
        }
        .foregroundStyle(outcome == .yes ? DSColor.positive : DSColor.negative)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .dsRaised(face: tint, lip: DSLip.tint(tint), cornerRadius: DSLayout.chipRadius, depth: DSDepth.medium)
    }
}
