//
//  TrendingChipRow.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// Horizontally scrolling sub-filter chips shown under the filter row while the rail is on
/// Trending. A leading "All" chip clears the filter (`onSelect(nil)`).
struct TrendingChipRow: View {
    let chips: [Tag]
    let selectedTagID: String?
    let onSelect: (String?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                DSChip("All", isActive: selectedTagID == nil) { onSelect(nil) }
                ForEach(chips) { tag in
                    DSChip(tag.label, isActive: selectedTagID == tag.id) { onSelect(tag.id) }
                }
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.vertical, 6)
        }
    }
}
