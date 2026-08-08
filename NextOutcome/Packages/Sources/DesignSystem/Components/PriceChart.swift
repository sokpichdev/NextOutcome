//
//  PriceChart.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI
import Charts
import Foundation

/// A single point in a price/probability history, used to plot line and area
/// charts throughout the app (portfolio sparklines, market price charts, etc.).
public struct PricePoint: Identifiable, Sendable {
    /// A unique identifier so SwiftUI can diff points in a chart.
    public let id = UUID()
    /// The timestamp this price was recorded at (the chart's x-axis value).
    public let date: Date
    /// The price as a 0…1 fraction (the chart's y-axis value), e.g. 0.62 = 62¢.
    public let price: Double // 0...1 (fraction, e.g. 0.62 = 62¢)

    /// Creates a price point.
    /// - Parameters:
    ///   - date: The timestamp of this price.
    ///   - price: The price as a 0…1 fraction.
    public init(date: Date, price: Double) {
        self.date = date
        self.price = price
    }
}


/// Swift Charts area+line price chart with gradient fill, grid, axis, and a glowing end dot.
///
/// Used for single-outcome price/probability history charts (e.g. a binary
/// market's Yes-price over time, or a portfolio value sparkline). For charting
/// several outcomes at once, see `MultiSeriesChart` instead.
public struct PriceChart: View {
    /// The price history points to plot, in chronological order.
    let data: [PricePoint]
    /// The color used for the line and the glowing end dot.
    let color: Color
    /// The gradient used to fill the area under the line.
    let gradient: LinearGradient

    /// Creates a price chart.
    /// - Parameters:
    ///   - data: The price history to plot.
    ///   - color: The line/dot color. Defaults to `DSColor.positive` (green).
    ///   - gradient: The area fill gradient. Defaults to `DSGradient.positiveArea`.
    public init(data: [PricePoint], color: Color = DSColor.positive, gradient: LinearGradient = DSGradient.positiveArea) {
        self.data = data
        self.color = color
        self.gradient = gradient
    }

    public var body: some View {
        Chart(data) { point in
            AreaMark(
                x: .value("Date", point.date),
                y: .value("Price", point.price)
            )
            .foregroundStyle(gradient)
            LineMark(
                x: .value("Date", point.date),
                y: .value(("Price"), point.price)
            )
            .foregroundStyle(color)
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) {
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(DSColor.separator)
                AxisValueLabel()
                    .foregroundStyle(DSColor.textSecondary)
                    .font(DSFont.caption2)
            }
        }
        .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(DSColor.separator)
//                        AxisValueLabel(format: .percent)
                        AxisValueLabel(format: FloatingPointFormatStyle<Double>.Percent())
                            .foregroundStyle(DSColor.textSecondary)
                            .font(DSFont.caption2)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if let last = data.last {
                        // Glowing end dot — positioned by chart geometry is approximate;
                        // for pixel-perfect placement use chartOverlay with proxy.position(for:)
                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)
                            .shadow(color: color.opacity(0.7), radius: 6)
                            .padding(4)
                    }
                }
            }
        }
