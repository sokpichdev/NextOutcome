//
//  SubTopicChipRow.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// Horizontally scrolling sub-topic chips shown under the filter row — Gamma's own carousel
/// row for the selected category. A leading "All" chip clears the filter (`onSelect(nil)`).
struct SubTopicChipRow: View {
    /// The category's sub-topic tags, in the server's rank order.
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
