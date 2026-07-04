import SwiftUI
import Charts

/// One labeled, colored price line. `points` are 0…1 fractions.
public struct PriceSeries: Identifiable, Sendable {
    public let id: String
    public let label: String
    public let color: Color
    public let points: [PricePoint]
    public init(id: String, label: String, color: Color, points: [PricePoint]) {
        self.id = id; self.label = label; self.color = color; self.points = points
    }
}

/// Multi-outcome line chart with a legend (colored dot + label + latest %). No area fill.
public struct MultiSeriesChart: View {
    private let series: [PriceSeries]
    public init(series: [PriceSeries]) { self.series = series }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            legend
            Chart {
                ForEach(series) { s in
                    ForEach(s.points) { p in
                        LineMark(x: .value("Date", p.date), y: .value("Price", p.price))
                            .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    .foregroundStyle(by: .value("Series", s.label))
                }
            }
            .chartForegroundStyleScale(domain: series.map(\.label), range: series.map(\.color))
            .chartLegend(.hidden)
            .chartYScale(domain: yDomain)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(DSColor.separator)
                    AxisValueLabel(format: FloatingPointFormatStyle<Double>.Percent())
                        .foregroundStyle(DSColor.textSecondary)
                        .font(DSFont.caption2)
                }
            }
        }
    }

    /// Y range scaled to the data (lowest→highest across every series) with ~10%
    /// headroom, clamped to 0…1 — so lines fill the chart instead of hugging the
    /// bottom of a fixed 0…1 axis.
    private var yDomain: ClosedRange<Double> {
        let prices = series.flatMap { $0.points.map(\.price) }
        guard let minP = prices.min(), let maxP = prices.max() else { return 0...1 }
        guard maxP > minP else {
            // Flat data: center a small window around the single value.
            let lower = Swift.max(0, minP - 0.05)
            let upper = Swift.min(1, maxP + 0.05)
            return lower...Swift.max(upper, lower + 0.01)
        }
        let pad = Swift.max((maxP - minP) * 0.1, 0.01)
        return Swift.max(0, minP - pad)...Swift.min(1, maxP + pad)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(series) { s in
                HStack(spacing: 6) {
                    Circle().fill(s.color).frame(width: 8, height: 8)
                    Text(s.label).font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
                    if let last = s.points.last {
                        Text(String(format: "%.1f%%", last.price * 100))
                            .font(DSFont.caption.bold()).foregroundStyle(DSColor.textPrimary)
                    }
                }
            }
        }
    }
}
