//
//  PoliticsHubViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import Foundation
import MarketsDomain

/// Drives the Politics hub (2026 Midterms): loads every race under the "midterms" tag plus
/// the "referendums" tag, splits out the two headline party-control markets, and classifies
/// the rest into Senate/House/Governor races (via `ChamberClassifier`) for the searchable,
/// chamber-tabbed all-races list.
@MainActor
@Observable
public final class PoliticsHubViewModel {
    /// The hub's overall load state.
    public enum State: Equatable {
        case idle, loading, loaded
        case failed(String)
    }

    /// Gamma tag covering every 2026 midterms race and the two party-control markets.
    static let midtermsTagID = "102289"
    /// Gamma tag covering 2026 ballot-measure/referendum markets.
    static let referendumsTagID = "104240"
    /// Slugs of the two headline aggregate markets, split out of the race list on load.
    static let senateControlSlug = "which-party-will-win-the-senate-in-2026"
    static let houseControlSlug = "which-party-will-win-the-house-in-2026"
    static let balanceOfPowerSlug = "balance-of-power-2026-midterms"

    /// Nov 3, 2026 — the 2026 US midterm election day, for the hero countdown.
    public static let electionDate: Date = {
        var components = DateComponents()
        components.year = 2026; components.month = 11; components.day = 3
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }()

    /// The current load state.
    public private(set) var state: State = .idle
    /// Every classified Senate/House/Governor race (aggregate markets excluded).
    public private(set) var races: [Event] = []
    /// Ballot-measure/referendum events.
    public private(set) var referendums: [Event] = []
    /// "Which party will win the Senate in 2026?" — the headline Senate-control market.
    public private(set) var senateControlEvent: Event?
    /// "Which party will win the House in 2026?" — the headline House-control market.
    public private(set) var houseControlEvent: Event?
    /// "Balance of Power: 2026 Midterms" — the multi-scenario aggregate market.
    public private(set) var balanceOfPowerEvent: Event?

    /// The selected chamber tab for the all-races list.
    public var selectedChamber: Chamber = .senate
    /// The current race-search query (client-side title filter).
    public var searchQuery: String = ""

    /// Loads a tag's events, unpaginated.
    private let fetchAllEvents: FetchAllEventsUseCase

    /// Creates the view model.
    /// - Parameter fetchAllEvents: Loads a tag's events, unpaginated.
    public init(fetchAllEvents: FetchAllEventsUseCase) {
        self.fetchAllEvents = fetchAllEvents
    }

    /// Loads the hub's data. Idempotent: skips if already loading/loaded.
    public func loadIfNeeded() async {
        guard case .idle = state else { return }
        await load()
    }

    /// Reloads from scratch (pull-to-refresh).
    public func refresh() async {
        await load()
    }

    /// Fetches the midterms + referendums tags in parallel, then splits the midterms events
    /// into the two headline control markets, the balance-of-power market, and every other
    /// individual race (classified by `ChamberClassifier`; non-race thematic markets under the
    /// same tag are dropped).
    private func load() async {
        state = .loading
        do {
            async let midterms = fetchAllEvents.execute(tagID: Self.midtermsTagID)
            async let refs = fetchAllEvents.execute(tagID: Self.referendumsTagID)
            let (midtermsEvents, referendumEvents) = try await (midterms, refs)

            var raceList: [Event] = []
            for event in midtermsEvents {
                switch event.slug {
                case Self.senateControlSlug: senateControlEvent = event
                case Self.houseControlSlug: houseControlEvent = event
                case Self.balanceOfPowerSlug: balanceOfPowerEvent = event
                default:
                    if ChamberClassifier.classify(title: event.title).chamber != .other {
                        raceList.append(event)
                    }
                }
            }
            races = raceList
            referendums = referendumEvents
            state = .loaded
        } catch {
            state = .failed("Couldn't load Politics. Pull to refresh.")
        }
    }

    /// Races in the selected chamber matching the current search query (case-insensitive
    /// substring on title), sorted alphabetically.
    public var filteredRaces: [Event] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return races
            .filter { ChamberClassifier.classify(title: $0.title).chamber == selectedChamber }
            .filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
            .sorted { $0.title < $1.title }
    }

    /// The number of loaded races in a given chamber, for the tab labels (e.g. "Senate 35").
    public func raceCount(for chamber: Chamber) -> Int {
        races.reduce(into: 0) { count, event in
            if ChamberClassifier.classify(title: event.title).chamber == chamber { count += 1 }
        }
    }
}
