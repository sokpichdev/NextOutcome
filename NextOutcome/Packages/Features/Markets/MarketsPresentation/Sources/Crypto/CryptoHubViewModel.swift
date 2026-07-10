import Foundation
import MarketsDomain

/// Drives the Crypto hub: fetches every event under the Crypto tag, classifies each into
/// a `CryptoMarketKind`, and exposes the sub-tab/sort/period-filtered list the view renders.
@MainActor
@Observable
public final class CryptoHubViewModel {
    /// The hub's overall load state.
    public enum State: Equatable { case idle, loading, loaded, failed(String) }

    /// The Crypto hub's sub-tabs.
    public enum SubTab: CaseIterable, Hashable {
        case all, upDown, aboveBelow, priceRange, hitPrice

        /// The `CryptoMarketKind` this sub-tab shows, or `nil` for `.all` (shows every kind).
        var kind: CryptoMarketKind? {
            switch self {
            case .all: return nil
            case .upDown: return .upDown
            case .aboveBelow: return .aboveBelow
            case .priceRange: return .priceRange
            case .hitPrice: return .hitPrice
            }
        }
    }

    /// Sort options backed by real `Event`/`Market` fields.
    public enum SortOption: CaseIterable, Equatable { case volume, endingSoon }

    /// Period filter, keyword-matched against the event title.
    public enum Period: CaseIterable, Equatable { case all, daily, weekly, monthly }

    /// The current load state.
    public private(set) var state: State = .idle
    /// Every fetched event, paired with its classified kind. `.other`-kind events are
    /// excluded here already, since no sub-tab (including `.all`) can render them.
    public private(set) var classifiedEvents: [(event: Event, kind: CryptoMarketKind)] = []
    /// The tag id `loadIfNeeded`/`refresh` last fetched, once known.
    private var loadedTagID: String?

    /// The selected sub-tab.
    public var selectedSubTab: SubTab = .all
    /// The selected sort option.
    public var sortOption: SortOption = .volume
    /// The selected period filter.
    public var period: Period = .all

    private let fetchAllEvents: FetchAllEventsUseCase

    /// Creates the view model.
    /// - Parameter fetchAllEvents: Loads a tag's events, unpaginated.
    public init(fetchAllEvents: FetchAllEventsUseCase) {
        self.fetchAllEvents = fetchAllEvents
    }

    /// Fetches `tagID`'s events and classifies them, unless already loaded for this tag id.
    /// - Parameter tagID: The Crypto tag's live Gamma id.
    public func loadIfNeeded(tagID: String) async {
        guard loadedTagID != tagID else { return }
        await load(tagID: tagID)
    }

    /// Re-fetches using the last-loaded tag id (pull-to-refresh). No-op before the first load.
    public func refresh() async {
        guard let tagID = loadedTagID else { return }
        await load(tagID: tagID)
    }

    private func load(tagID: String) async {
        state = .loading
        do {
            let events = try await fetchAllEvents.execute(tagID: tagID)
            classifiedEvents = events
                .map { (event: $0, kind: CryptoMarketKind.classify($0)) }
                .filter { $0.kind != .other }
            loadedTagID = tagID
            state = .loaded
        } catch {
            state = .failed("Couldn't load Crypto. Pull to refresh.")
        }
    }

    /// `classifiedEvents` filtered by `selectedSubTab`/`period`, sorted by `sortOption`.
    public var visibleEvents: [(event: Event, kind: CryptoMarketKind)] {
        var events = classifiedEvents
        if let kind = selectedSubTab.kind {
            events = events.filter { $0.kind == kind }
        }
        if period != .all {
            events = events.filter { matches(period: period, title: $0.event.title) }
        }
        switch sortOption {
        case .volume:
            events.sort { $0.event.volume > $1.event.volume }
        case .endingSoon:
            events.sort { endingSoonSortKey($0.event) < endingSoonSortKey($1.event) }
        }
        return events
    }

    /// Case-insensitive keyword match of the period against the event title.
    private func matches(period: Period, title: String) -> Bool {
        let lower = title.lowercased()
        switch period {
        case .all: return true
        case .daily: return lower.contains("daily")
        case .weekly: return lower.contains("weekly")
        case .monthly: return lower.contains("monthly")
        }
    }

    /// The soonest market end date across an event's markets, for "Ending Soon" sort.
    /// Events with no end date on any market sort last.
    private func endingSoonSortKey(_ event: Event) -> Date {
        event.markets.compactMap(\.endDate).min() ?? .distantFuture
    }
}
