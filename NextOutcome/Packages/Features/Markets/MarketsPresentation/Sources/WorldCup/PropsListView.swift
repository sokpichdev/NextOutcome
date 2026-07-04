//
//  PropsListView.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// The hub's Props tab: All / Awards / Player H2H / Group Futures chips over the series'
/// non-game events, rendered with the standard home cards.
struct PropsListView: View {
    let props: [Event]
    @Binding var filter: PropsFilter

    var body: some View {
        VStack(spacing: DSLayout.spacing) {
            FilterChipRow(
                items: PropsFilter.allCases.map { .init(id: $0, label: $0.title) },
                selectedID: filter,
                onSelect: { filter = $0 }
            )
            .padding(.horizontal, -DSLayout.margin) // chips row manages its own margins

            let visible = props.filter { filter.matches($0) }.sorted { $0.volume > $1.volume }
            if visible.isEmpty {
                ContentUnavailableView("No markets", systemImage: "tray")
                    .padding(.vertical, DSLayout.spacingXLarge)
            } else {
                LazyVStack(spacing: DSLayout.spacing) {
                    ForEach(visible) { event in
                        NavigationLink(value: event) {
                            HomeCard(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
