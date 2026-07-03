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
            .chartYScale(domain: 0...1)
        }
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(series) { s in
                HStack(spacing: 6) {
                    Circle().fill(s.color).frame(width: 8, height: 8)
                    Text(s.label).font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
                    if let last = s.points.last {
                        Text("\(Int((last.price * 100).rounded()))%")
                            .font(DSFont.caption).foregroundStyle(DSColor.textPrimary)
                    }
                }
            }
        }
    }
}
