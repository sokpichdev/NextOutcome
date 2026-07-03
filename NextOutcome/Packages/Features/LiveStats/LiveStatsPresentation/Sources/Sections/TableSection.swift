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

struct TableSection: View {
    let match: MatchState?
    var body: some View { UnavailableRow() }
}

struct H2HSection: View {
    let match: MatchState?
    var body: some View { UnavailableRow() }
}
