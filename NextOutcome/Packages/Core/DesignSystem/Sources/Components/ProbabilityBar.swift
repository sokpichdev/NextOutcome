//
//  ProbabilityBar.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

/// horizontal split bar: green(yes) on left, red(no) on right.
/// `yesFraction` is 0...1.

public struct ProbabilityBar: View {
    let yesFraction: Double
    
    public init(yesFraction: Double) {
        self.yesFraction = max(0, min(1, yesFraction))
    }
    
    public var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(DSColor.positive)
                    .frame(width: geo.size.width * yesFraction)
                RoundedRectangle(cornerRadius: 3)
                    .fill(DSColor.negative)
            }
        }
        .frame(height: 6)
    }
}
