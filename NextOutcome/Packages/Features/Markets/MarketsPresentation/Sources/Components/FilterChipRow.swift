//
//  FilterChipRow.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import SwiftUI
import DesignSystem

/// Horizontally scrolling capsule filter chips with a single selection. Shared by the
/// Trending sub-filter row and the World Cup Props filter.
struct FilterChipRow<ID: Hashable>: View {
    /// One selectable chip: an identity value plus its display label.
    struct Item {
        /// The chip's identity, compared against `selectedID`.
        let id: ID
        /// The chip's display text.
        let label: String
    }

    /// The chips to show.
    let items: [Item]
    /// The currently-selected chip's id.
    let selectedID: ID
    /// Called with the chosen id when a chip is tapped.
    let onSelect: (ID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.id) { item in
                    DSChip(item.label, isActive: selectedID == item.id) { onSelect(item.id) }
                }
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.vertical, 6)
        }
    }
}
