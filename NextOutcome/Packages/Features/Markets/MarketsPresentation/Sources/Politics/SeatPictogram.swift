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

/// A dot-grid pictogram of a chamber's current seats, as two separate party blocks side by
/// side (Republicans left, Democrats right) — matching the web's
/// "49 REPUBLICANS ⓘ / 51 DEMOCRATS ⓘ" layout.
struct SeatPictogram: View {
    let composition: ChamberComposition
    /// Dots per row within each party's block.
    private let columns = 12
    private let dotSize: CGFloat = 8
    private let spacing: CGFloat = 4

    var body: some View {
        HStack(alignment: .top, spacing: DSLayout.spacingLarge) {
            partyBlock(count: composition.republicans, label: "REPUBLICANS", color: DSColor.negative)
            partyBlock(count: composition.democrats, label: "DEMOCRATS", color: DSColor.accent)
        }
    }

    private func partyBlock(count: Int, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
            grid(count: count, color: color)
            HStack(spacing: 4) {
                Text("\(count)")
                    .font(DSFont.caption.bold())
                    .foregroundStyle(color)
                Text(label)
                    .font(DSFont.caption2)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
    }

    private func grid(count: Int, color: Color) -> some View {
        let rows = Int(ceil(Double(count) / Double(columns)))
        return VStack(alignment: .leading, spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { col in
                        let dotIndex = row * columns + col
                        if dotIndex < count {
                            Circle()
                                .fill(color)
                                .frame(width: dotSize, height: dotSize)
                        }
                    }
                }
            }
        }
    }
}
