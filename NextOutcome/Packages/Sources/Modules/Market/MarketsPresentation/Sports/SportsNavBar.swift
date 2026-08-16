//
//  SportsNavBar.swift
//  NextOutcome
//
//  Created by Sok Pich on 16/08/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// The Sports hub's top chip row: Live / Futures mode toggles, one chip per sport with
/// something open to trade, and a trailing More chip opening the full taxonomy.
///
/// Every chip selects its content in place on the same screen — none of them navigate,
/// matching the behaviour established for the mode toggles.
struct SportsNavBar: View {
    /// The selected top-level mode (Live/Futures), two-way bound.
    @Binding var mode: SportsHubViewModel.Mode
    /// The sports with open events, in catalogue order.
    let groups: [SportGroup]
    /// The selected sport, if any. Selecting Live/Futures clears this.
    @Binding var selectedGroup: SportGroup?
    /// Whether the All Sports sheet is presented, two-way bound.
    @Binding var isShowingAllSports: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                modeChip(title: "Live", glyph: "dot.radiowaves.left.and.right",
                         isActive: mode == .live && selectedGroup == nil,
                         showsLiveDot: groups.contains(where: \.hasLive)) {
                    mode = .live
                    selectedGroup = nil
                }
                modeChip(title: "Futures", glyph: "chart.bar.fill",
                         isActive: mode == .futures && selectedGroup == nil,
                         showsLiveDot: false) {
                    mode = .futures
                    selectedGroup = nil
                }
                ForEach(groups) { group in
                    Button { selectedGroup = group } label: {
                        groupChip(group, isActive: selectedGroup?.id == group.id)
                    }
                    .buttonStyle(.plain)
                }
                Button { isShowingAllSports = true } label: {
                    chipLabel(title: "More", glyph: "ellipsis", isActive: false)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("All Sports")
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.vertical, 6)
        }
    }

    /// One Live/Futures mode toggle, optionally carrying the red live dot.
    private func modeChip(
        title: String, glyph: String, isActive: Bool, showsLiveDot: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if showsLiveDot {
                    Circle().fill(DSColor.negative).frame(width: 6, height: 6)
                } else {
                    Image(systemName: glyph)
                }
                Text(title)
            }
            .modifier(ChipStyle(isActive: isActive))
        }
        .buttonStyle(.plain)
    }

    /// A sport chip: its league key art (falling back to the group glyph), name, and the
    /// count of open events.
    private func groupChip(_ group: SportGroup, isActive: Bool) -> some View {
        HStack(spacing: 6) {
            icon(for: group)
            Text(group.name)
            Text(MarketFormatting.compactShares(Decimal(group.activeEventCount)))
                .foregroundStyle(isActive ? .white.opacity(0.7) : DSColor.textSecondary)
        }
        .modifier(ChipStyle(isActive: isActive))
    }

    /// The group's key art when a league supplies it, else its SF Symbol.
    @ViewBuilder
    private func icon(for group: SportGroup) -> some View {
        if let url = group.leagues.first?.iconURL {
            AsyncImage(url: url) { $0.resizable().scaledToFit() } placeholder: {
                Image(systemName: group.glyph)
            }
            .frame(width: 14, height: 14)
        } else {
            Image(systemName: group.glyph)
        }
    }

    /// The plain chip style, for chips with no icon or count of their own.
    private func chipLabel(title: String, glyph: String, isActive: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: glyph)
            Text(title)
        }
        .modifier(ChipStyle(isActive: isActive))
    }
}

/// The shared chip shape, so mode toggles, sport chips, and More read as one row.
private struct ChipStyle: ViewModifier {
    /// Whether the chip is selected.
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .font(DSFont.caption.bold())
            .foregroundStyle(isActive ? .white : DSColor.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isActive ? AnyView(DSGradient.accent) : AnyView(DSColor.surface))
            .clipShape(Capsule())
    }
}
