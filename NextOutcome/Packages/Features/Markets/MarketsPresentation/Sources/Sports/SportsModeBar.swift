//
//  SportsModeBar.swift
//  NextOutcome
//
//  Created by Sok Pich on 06/07/2026.
//

import SwiftUI
import DesignSystem

/// The Sports hub's top chip row: Live / Futures mode toggles plus league chips (World Cup,
/// Wimbledon, MLB, …). Mode chips update `mode`; league chips are `NavigationLink`s pushing
/// `SportsLeague` values onto the enclosing stack.
struct SportsModeBar: View {
    /// The selected top-level mode (Live/Futures), two-way bound.
    @Binding var mode: SportsHubViewModel.Mode
    /// The league chips to show after the mode toggles.
    let leagues: [SportsLeague]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                modeChip(title: "Live", glyph: "dot.radiowaves.left.and.right", isActive: mode == .live) {
                    mode = .live
                }
                modeChip(title: "Futures", glyph: "chart.bar.fill", isActive: mode == .futures) {
                    mode = .futures
                }
                ForEach(leagues) { league in
                    NavigationLink(value: league) {
                        chipLabel(title: league.title, glyph: league.glyph, isActive: false)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.vertical, 6)
        }
    }

    /// One tappable icon + label chip (the Live/Futures mode toggles).
    private func modeChip(title: String, glyph: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            chipLabel(title: title, glyph: glyph, isActive: isActive)
        }
        .buttonStyle(.plain)
    }

    /// The chip's visual style, shared by mode toggles and league navigation links.
    private func chipLabel(title: String, glyph: String, isActive: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: glyph)
            Text(title)
        }
        .font(DSFont.caption.bold())
        .foregroundStyle(isActive ? .white : DSColor.textSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isActive ? AnyView(DSGradient.accent) : AnyView(DSColor.surface))
        .clipShape(Capsule())
    }
}
