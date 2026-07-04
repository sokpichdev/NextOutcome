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
    struct Item {
        let id: ID
        let label: String
    }

    let items: [Item]
    let selectedID: ID
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
