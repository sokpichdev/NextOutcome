//
//  CandleChartScale.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/08/2026.
//

import Foundation

/// A dollar y-range for the candle chart that deliberately refuses to move on every tick.
///
/// The naive `min(low)…max(high)` domain is recomputed from scratch each time an RTDS tick
/// stretches the forming candle. Every change rescales all the candles, resizes the
/// minimum-body floor, and changes the widest y-axis label — and in a
/// `chartScrollableAxes` chart the axis's reserved width feeds back into the *plot* width,
/// hence into every candle's x position. That feedback loop is half of the chart's
/// sideways shimmy.
///
/// So the band is quantised onto a "nice" step and only re-quantised when the data
/// actually leaves it (grow) or has shrunk well inside it (`shrinkThreshold`). The shrink
/// threshold is what stops a series brushing its own boundary from flapping between two
/// bands every frame.
///
/// Pure and value-typed so the hysteresis is unit-testable without ever building a chart.
struct CandleChartScale: Equatable, Sendable {
    /// The band currently rendered; `nil` until the first `absorb`.
    private(set) var domain: ClosedRange<Double>?

    /// The data span must fall below this fraction of the band before the band re-tightens.
    /// Loose enough that ordinary intra-window movement never triggers a re-fit.
    static let shrinkThreshold = 0.55
    /// Head-room added above and below the raw extremes before quantising.
    /// Kept compact (4%) so candle bodies and wicks maximize their vertical height in the chart frame.
    static let padding = 0.04
    /// Roughly how many quantisation steps should span the band. Three axis marks read
    /// comfortably against six steps while keeping the dynamic range compact.
    static let targetSteps = 6.0

    /// Folds fresh extremes into the band.
    /// - Parameters:
    ///   - low: The lowest price the chart must show.
    ///   - high: The highest price the chart must show.
    /// - Returns: `true` only when the rendered band actually changed, so callers can skip
    ///   republishing — an in-band tick must cost the chart nothing.
    @discardableResult
    mutating func absorb(low: Double, high: Double) -> Bool {
        guard low.isFinite, high.isFinite else { return false }
        let candidate = Self.quantised(low: low, high: high)
        guard let current = domain else {
            domain = candidate
            return true
        }
        let fits = low >= current.lowerBound && high <= current.upperBound
        let stillFills = (high - low) >= (current.upperBound - current.lowerBound) * Self.shrinkThreshold
        // Inside the band and still filling it: nothing to do, whatever the candidate says.
        if fits && stillFills { return false }
        guard candidate != current else { return false }
        domain = candidate
        return true
    }

    /// Pads `low…high` then snaps the bounds outwards onto multiples of a nice step.
    static func quantised(low: Double, high: Double) -> ClosedRange<Double> {
        let (lo, hi) = padded(low: low, high: high)
        let step = step(low: low, high: high)
        let lower = (lo / step).rounded(.down) * step
        let upper = (hi / step).rounded(.up) * step
        return lower...(upper > lower ? upper : lower + step)
    }

    /// The quantisation step `quantised(low:high:)` snaps to. Exposed so callers — and
    /// tests — can reason about the grid without re-deriving the padding rule.
    static func step(low: Double, high: Double) -> Double {
        let (lo, hi) = padded(low: low, high: high)
        return niceStep((hi - lo) / targetSteps)
    }

    /// `low…high` widened by `padding`, so the extremes aren't glued to the frame edge.
    /// A perfectly flat series still gets a band, or the line lands on the edge itself.
    private static func padded(low: Double, high: Double) -> (Double, Double) {
        let lo = Swift.min(low, high)
        let hi = Swift.max(low, high)
        let pad = hi - lo < .ulpOfOne ? Swift.max(abs(hi) * 0.001, 1) : (hi - lo) * padding
        return (lo - pad, hi + pad)
    }

    /// The nearest 1, 2, 2.5 or 5 × 10ⁿ at or above `raw` — the same ladder axis labels
    /// use, so quantised bounds format to a predictable number of digits (which is what
    /// lets the axis gutter keep a fixed width).
    static func niceStep(_ raw: Double) -> Double {
        guard raw > 0, raw.isFinite else { return 1 }
        let magnitude = pow(10, log10(raw).rounded(.down))
        let normalised = raw / magnitude
        let factor: Double = normalised <= 1 ? 1
            : normalised <= 2 ? 2
            : normalised <= 2.5 ? 2.5
            : normalised <= 5 ? 5
            : 10
        return factor * magnitude
    }
}
