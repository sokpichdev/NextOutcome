//
//  SeatPictogram.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import SwiftUI
import DesignSystem

/// A chamber's current seat composition (party counts), for the "current control" pictogram
/// shown under each headline control card. Fixed reference data — Gamma has no live seat-count
/// endpoint — so this reflects composition as of this build and should be refreshed each
/// Congress/term.
public struct ChamberComposition: Sendable {
    /// Current Republican-held seats.
    public let republicans: Int
    /// Current Democrat-held seats (including independents who caucus with them).
    public let democrats: Int

    public init(republicans: Int, democrats: Int) {
        self.republicans = republicans
        self.democrats = democrats
    }

    /// 119th Congress composition.
    public static let senate = ChamberComposition(republicans: 53, democrats: 47)
    public static let house = ChamberComposition(republicans: 220, democrats: 213)
}

/// A dot-grid pictogram of a chamber's current seats, grouped by party — matching the web's
/// "49 REPUBLICANS / 51 DEMOCRATS"-style seat grids.
struct SeatPictogram: View {
    let composition: ChamberComposition
    /// Dots per row.
    private let columns = 15
    private let dotSize: CGFloat = 8
    private let spacing: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
            grid
            HStack(spacing: DSLayout.spacing) {
                legendLabel("\(composition.republicans) REPUBLICANS", color: DSColor.negative)
                legendLabel("\(composition.democrats) DEMOCRATS", color: DSColor.accent)
            }
        }
    }

    private var grid: some View {
        let total = composition.republicans + composition.democrats
        let rows = Int(ceil(Double(total) / Double(columns)))
        return VStack(alignment: .leading, spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { col in
                        let dotIndex = row * columns + col
                        if dotIndex < total {
                            Circle()
                                .fill(dotIndex < composition.republicans ? DSColor.negative : DSColor.accent)
                                .frame(width: dotSize, height: dotSize)
                        }
                    }
                }
            }
        }
    }

    private func legendLabel(_ text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(text).font(DSFont.caption2).foregroundStyle(DSColor.textSecondary)
        }
    }
}
