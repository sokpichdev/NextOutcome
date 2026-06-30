//
//  DSButtonStyle.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

public struct DSPrimaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFont.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(DSGradient.accent)
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.pillRadius))
            .glowAccent()
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

public struct DSBuyYesButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFont.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(DSGradient.positive)
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.pillRadius))
            .glowPositive()
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

public struct DSBuyNoButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFont.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(DSGradient.negative)
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.pillRadius))
            .glowNegative()
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
