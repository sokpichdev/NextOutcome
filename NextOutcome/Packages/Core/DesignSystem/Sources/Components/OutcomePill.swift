//
//  OutcomePill.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

public struct OutcomePill: View {
    public enum Outcome { case yes, no }
    let outcome: Outcome
    let value: String
    
    public init(_ outcome: Outcome, value: String) {
        self.outcome = outcome
        self.value = value
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Text(outcome == .yes ? "Yes" : "No")
                .font(DSFont.caption.bold())
            Text(value)
                .font(DSFont.priceSmall)
        }
        .foregroundStyle(outcome == .yes ? DSColor.positive : DSColor.negative)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            outcome == .yes ? DSColor.positiveTint : DSColor.negativeTint
        )
        .clipShape(Capsule())
    }
}
