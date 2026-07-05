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
    /// The derived trending tags to show as chips.
    let chips: [Tag]
    /// The selected tag id, or `nil` for "All".
    let selectedTagID: String?
    /// Called with the chosen tag id (or `nil` for "All").
    let onSelect: (String?) -> Void

    var body: some View {
        FilterChipRow<String?>(
            items: [.init(id: nil, label: "All")] + chips.map { .init(id: $0.id, label: $0.label) },
            selectedID: selectedTagID,
            onSelect: onSelect
        )
    }
}
