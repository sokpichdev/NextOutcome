//
//  AllSportsSheet.swift
//  NextOutcome
//
//  Created by Sok Pich on 16/08/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// The full sport taxonomy, reached from the nav row's More chip.
///
/// A sport with several leagues expands to them; a sport that *is* a single league (MLB,
/// UFC — they carry their own tag rather than a parent sport's) renders flat with its count.
/// That split comes straight from the catalogue, not from a second hardcoded list.
struct AllSportsSheet: View {
    /// Every sport, including those with nothing open right now.
    let groups: [SportGroup]
    /// Called with the sport or league the user picked.
    let onSelect: (SportGroup) -> Void
    /// Dismisses the sheet after a selection.
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("ALL SPORTS") {
                    ForEach(groups) { group in
                        if group.isLeaf {
                            leafRow(group)
                        } else {
                            DisclosureGroup {
                                ForEach(group.leagues) { league in
                                    leagueRow(league, in: group)
                                }
                            } label: {
                                label(name: group.name, glyph: group.glyph,
                                      iconURL: group.leagues.first?.iconURL, count: nil)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(DSColor.background)
            .navigationTitle("Sports")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .presentationDetents([.large])
    }

    /// A single-league sport: tappable, with its count on the trailing edge.
    private func leafRow(_ group: SportGroup) -> some View {
        Button {
            onSelect(group)
            dismiss()
        } label: {
            label(name: group.name, glyph: group.glyph,
                  iconURL: group.leagues.first?.iconURL, count: group.activeEventCount)
        }
        .buttonStyle(.plain)
    }

    /// One league inside an expanded sport. Selecting it narrows the hub to that league
    /// alone, so it is wrapped in a single-league group of its own.
    private func leagueRow(_ league: SportLeague, in group: SportGroup) -> some View {
        Button {
            onSelect(SportGroup(id: league.id, name: league.name, glyph: group.glyph, leagues: [league]))
            dismiss()
        } label: {
            label(name: league.name, glyph: group.glyph,
                  iconURL: league.iconURL, count: league.activeEventCount)
                .padding(.leading, DSLayout.spacing)
        }
        .buttonStyle(.plain)
    }

    /// A row's icon, name, and optional trailing count.
    private func label(name: String, glyph: String, iconURL: URL?, count: Int?) -> some View {
        HStack(spacing: DSLayout.spacingMedium) {
            Group {
                if let iconURL {
                    AsyncImage(url: iconURL) { $0.resizable().scaledToFit() } placeholder: {
                        Image(systemName: glyph)
                    }
                } else {
                    Image(systemName: glyph)
                }
            }
            .frame(width: 22, height: 22)
            Text(name)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textPrimary)
            Spacer()
            if let count, count > 0 {
                Text(MarketFormatting.compactShares(Decimal(count)))
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .contentShape(Rectangle())
        .listRowBackground(DSColor.background)
    }
}
