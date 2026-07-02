//
//  PriceChart.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI
import Charts
import Foundation

public struct PricePoint: Identifiable, Sendable {
    public let id = UUID()
    public let date: Date
    public let price: Double // 0...1 (fraction, e.g. 0.62 = 62¢)
    
    public init(date: Date, price: Double) {
        self.date = date
        self.price = price
    }
}


/// Swift Charts area+line price chart with gradient fill, grid, axis, and a glowing end dot.
public struct PriceChart: View {
    let data: [PricePoint]
    let color: Color
    let gradient: LinearGradient
    
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
