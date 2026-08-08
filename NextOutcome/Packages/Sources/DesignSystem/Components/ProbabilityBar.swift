//
//  ProbabilityBar.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

/// horizontal split bar: green(yes) on left, red(no) on right.
/// `yesFraction` is 0...1.
///
/// Used to give an at-a-glance visual read of a binary market's implied
/// probability — a thin bar split into a green "Yes" segment and a red "No"
/// segment, sized proportionally to the current odds.
public struct ProbabilityBar: View {
    /// The fraction of the bar (0 to 1) filled with the "Yes" (green) segment.
    /// The remaining space is rendered as the "No" (red) segment.
    let yesFraction: Double

    /// Creates a probability bar.
    /// - Parameter yesFraction: The "Yes" probability to visualize. Automatically
    ///   clamped to the valid `0...1` range in case the caller passes an out-of-range value.
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
