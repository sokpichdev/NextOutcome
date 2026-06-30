//
//  ValuePnLHeader.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

/// portfolio / position value card with sparkline
public struct ValuePnLHeader: View {
    let title: String
    let value: String // e.g. "$1,240.55"
    let change: String // e.g. "▲ +$84.20 (7.3%) today"
    let isPositive: Bool
    let sparkData: [PricePoint]
    
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
