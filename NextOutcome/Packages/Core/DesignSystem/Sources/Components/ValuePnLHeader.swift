//
//  ValuePnLHeader.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

/// portfolio / position value card with sparkline
///
/// A highlighted `DSCard` showing a title (e.g. "Portfolio Value"), a large price
/// value, a colored change line (e.g. profit/loss today), and a small sparkline
/// chart underneath. Used at the top of the Portfolio screen and on individual
/// position detail views.
public struct ValuePnLHeader: View {
    /// The small label above the value, e.g. "Portfolio Value".
    let title: String
    /// The large formatted value to display prominently, e.g. "$1,240.55".
    let value: String // e.g. "$1,240.55"
    /// A formatted change description shown below the value, e.g. "▲ +$84.20 (7.3%) today".
    let change: String // e.g. "▲ +$84.20 (7.3%) today"
    /// Whether the change is positive (green) or negative (red). Controls the
    /// color of `change` text and the sparkline.
    let isPositive: Bool
    /// The data points used to draw the small sparkline chart at the bottom of the card.
    let sparkData: [PricePoint]

    /// Creates a value/PnL header card.
    /// - Parameters:
    ///   - title: The label above the value.
    ///   - value: The formatted value string to show prominently.
    ///   - change: The formatted change description.
    ///   - isPositive: Whether the change is positive (affects coloring).
    ///   - sparkData: The points to plot in the sparkline chart.
    public init(title: String, value: String, change: String, isPositive: Bool, sparkData: [PricePoint]) {
        self.title = title
        self.value = value
        self.change = change
        self.isPositive = isPositive
        self.sparkData = sparkData
    }

    public var body: some View {
        DSCard(highlighted: true) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                Text(value)
                    .font(DSFont.price)
                    .foregroundStyle(DSColor.textPrimary)
                Text(change)
                    .font(DSFont.subheadline)
                    .foregroundStyle(isPositive ? DSColor.positive : DSColor.negative)
                PriceChart(
                    data: sparkData,
                    color: isPositive ? DSColor.positive : DSColor.negative,
                    gradient: isPositive ? DSGradient.positiveArea : DSGradient.accentArea
                )
                .frame(height: 56)
            }
        }
    }
}
