//
//  EventDetailDestination.swift
//  NextOutcome
//
//  Created by Sok Pich on 13/08/2026.
//

import SwiftUI
import MarketsDomain

/// Registers the app's single answer to "which screen does tapping an event push?".
///
/// Esports matches get the purpose-built `EsportsMatchDetailView` — scoreboard, live score and
/// the Livestream tab — and everything else gets the generic `EventDetailView`.
///
/// The rule lives here, in one place, because the same match surfaces in several feeds. It
/// used to be registered inline by `EsportsHubView` alone, so the screen a live match opened
/// depended on the route the user happened to take to it: a scoreboard from the Esports hub,
/// a plain market list for the identical match in the All feed or in Search.
///
/// Falls back to the generic screen whenever the factory is absent (previews, tests), so a
/// host that hasn't injected it still navigates.
private struct EventDetailDestination: ViewModifier {
    /// Resolves the match's game for the status-line caption. Feeds that don't hold the
    /// catalogue pass the default, which just leaves the caption empty.
    let league: (Event) -> EsportsLeague?
    @Environment(\.esportsMatchDetailFactory) private var esportsMatchDetailFactory

    func body(content: Content) -> some View {
        content.navigationDestination(for: Event.self) { event in
            if EsportsCatalog.isEsportsMatch(event), let esportsMatchDetailFactory {
                EsportsMatchDetailView(viewModel: esportsMatchDetailFactory(event, league(event)))
            } else {
                EventDetailView(event: event)
            }
        }
    }
}

public extension View {
    /// Registers the shared `Event` navigation destination on this view's `NavigationStack`.
    ///
    /// Use this instead of declaring `navigationDestination(for: Event.self)` directly, so
    /// every feed sends a given event to the same screen. Register it **once** per stack —
    /// SwiftUI does not support two handlers for the same type in one `NavigationStack`, which
    /// is why `SportsHubView` scopes its registration to the branch that has no embedded child
    /// declaring its own.
    ///
    /// - Parameter league: Resolves an esports match's game, for the detail screen's caption.
    ///   Defaults to "unknown", which is correct for every feed that isn't the Esports hub.
    /// - Returns: The view with the destination registered.
    func eventDetailDestination(
        league: @escaping (Event) -> EsportsLeague? = { _ in nil }
    ) -> some View {
        modifier(EventDetailDestination(league: league))
    }
}
