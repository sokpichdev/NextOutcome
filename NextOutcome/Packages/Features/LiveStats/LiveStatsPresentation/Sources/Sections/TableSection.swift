//
//  TableSection.swift / H2HSection.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//
//  The public feed carries no standings or head-to-head history, so both sections render
//  the in-spec "Not available" placeholder. They exist as first-class sections so the chip
//  nav matches the live site and can light up if a richer feed arrives.

import SwiftUI
import LiveStatsDomain

/// The "Table" (standings) section. Always renders the "Not available" placeholder today
/// because the public feed carries no standings; kept as a first-class section so the
/// chip nav matches the live site.
struct TableSection: View {
    /// The current match snapshot (unused today; reserved for a richer feed).
    let match: MatchState?
    var body: some View { UnavailableRow() }
}

/// The "H2H" (head-to-head history) section. Always renders the "Not available"
/// placeholder today for the same reason as `TableSection`.
struct H2HSection: View {
    /// The current match snapshot (unused today; reserved for a richer feed).
    let match: MatchState?
    var body: some View { UnavailableRow() }
}
