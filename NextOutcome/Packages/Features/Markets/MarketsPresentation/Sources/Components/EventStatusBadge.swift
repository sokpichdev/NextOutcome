//
//  EventStatusBadge.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/08/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// The "LIVE"/"ENDED" pill shown on feed cards for sports and esports fixtures.
///
/// Renders nothing for ordinary markets, which carry neither flag. This exists because
/// Gamma's `ended` is orthogonal to `closed` — a finished match keeps `closed: false` while
/// its 24h volume holds it near the top of the `volume24hr` feed for hours, so without the
/// badge a finished game is indistinguishable from an upcoming one. See `Event.isEnded`.
public struct EventStatusBadge: View {
    /// The event whose fixture status to show.
    private let event: Event

    /// Creates the badge.
    /// - Parameter event: The event to read `isLive`/`isEnded` from.
    public init(event: Event) {
        self.event = event
    }

    public var body: some View {
        if event.isLive {
            StatusBadge("LIVE", color: DSColor.negative)
        } else if event.isEnded {
            StatusBadge("ENDED", color: DSColor.textSecondary)
        }
    }
}

#if DEBUG
private func _event(ended: Bool?, live: Bool?) -> Event {
    Event(id: "e", title: "LoL: Gen.G vs Hanwha Life", slug: "lol", markets: [],
          volume: 0, imageURL: nil, ended: ended, live: live)
}

#Preview("Event status badges") {
    VStack(alignment: .leading, spacing: 12) {
        EventStatusBadge(event: _event(ended: false, live: true))
        EventStatusBadge(event: _event(ended: true, live: false))
        EventStatusBadge(event: _event(ended: nil, live: nil))  // renders nothing
    }
    .padding()
    .background(DSColor.background)
}
#endif
