//
//  ChanceGauge.swift
//  NextOutcome
//

import SwiftUI

/// A full-circle "chance" gauge: a ring filled to `fraction` with a percent readout and a
/// "chance" caption in the center. Used on single-question cards in place of a probability
/// bar, matching the compact gauge style used on live/short-form markets.
public struct ChanceGauge: View {
    /// The fraction of the ring to fill (0...1).
    private let fraction: Double
    /// The formatted percent text shown in the center (e.g. "18%").
    private let percentText: String
    /// The ring's diameter.
    private let size: CGFloat

    /// Creates a chance gauge.
    /// - Parameters:
    ///   - fraction: The probability to visualize, clamped to `0...1`.
    ///   - percentText: The formatted percent string to show at the center.
    ///   - size: The ring's diameter. Defaults to 64.
    public init(fraction: Double, percentText: String, size: CGFloat = 64) {
        self.fraction = max(0, min(1, fraction))
        self.percentText = percentText
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(DSColor.separator, style: .init(lineWidth: 5, lineCap: .round))
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(DSColor.negative, style: .init(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(percentText)
                    .font(DSFont.subheadline.bold())
                    .foregroundStyle(DSColor.textPrimary)
                Text("chance")
                    .font(DSFont.caption2)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .frame(width: size, height: size)
    }
}
