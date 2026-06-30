//
//  Glow.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

public extension View {
    func glowAccent(radius: CGFloat = 12) -> some View {
        self.shadow(color: DSColor.accent.opacity(0.55), radius: radius)
    }
    
    func glowPositive(radius: CGFloat = 12) -> some View {
        self.shadow(color: DSColor.positive.opacity(0.55), radius: radius)
    }
    
    func glowNegative(radius: CGFloat = 12) -> some View {
        self.shadow(color: DSColor.negative.opacity(0.55), radius: radius)
    }
}
