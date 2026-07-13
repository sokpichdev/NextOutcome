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

    /// Sort options backed by real `Event`/`Market` fields. Matches web's sort menu order,
    /// minus "Earn 3.25%" — a separate USDC-yield feature with no backing data or UI
    /// anywhere in this app, shown as a disabled row in the view instead of a case here.
    public enum SortOption: CaseIterable, Equatable { case volume24hr, totalVolume, liquidity, newest, endingSoon, competitive }

    /// Period filter, keyword-matched against the event title.
    public enum Period: CaseIterable, Equatable { case all, daily, weekly, monthly }

    /// Recurrence-based timeframe buckets shown as chips above the sub-tab row. Only the 4
    /// buckets visible without opening the deferred "More" sheet.
    public enum Timeframe: CaseIterable, Equatable { case all, fiveMin, fifteenMin, hourly }

    /// The current load state.
    public private(set) var state: State = .idle
    /// Every fetched event, paired with its classified kind. `.other`-kind events are
    /// excluded here already, since no sub-tab (including `.all`) can render them.
    public private(set) var classifiedEvents: [(event: Event, kind: CryptoMarketKind)] = []
    /// The tag id `loadIfNeeded`/`refresh` last fetched, once known.
    private var loadedTagID: String?

    /// The selected sub-tab.
    public var selectedSubTab: SubTab = .all
    /// The selected sort option. Defaults to `.volume24hr`, matching web's default.
    public var sortOption: SortOption = .volume24hr
    /// The selected period filter.
    public var period: Period = .all
    /// The selected recurrence timeframe.
    public var selectedTimeframe: Timeframe = .all
    /// Case-insensitive substring match against the event title.
    public var searchQuery: String = ""

    private let fetchAllEvents: FetchAllEventsUseCase
    /// The current time, injected so the expired-window filter is deterministic in tests.
    private let now: () -> Date

    /// Creates the view model.
    /// - Parameters:
    ///   - fetchAllEvents: Loads a tag's events, unpaginated.
    ///   - now: Supplies the current time for the expired-window filter. Defaults to `Date()`.
    public init(fetchAllEvents: FetchAllEventsUseCase, now: @escaping () -> Date = { Date() }) {
        self.fetchAllEvents = fetchAllEvents
        self.now = now
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
                .filter { isWindowLive($0.event) }
            loadedTagID = tagID
            state = .loaded
        } catch {
            state = .failed("Couldn't load Crypto. Pull to refresh.")
        }
    }

    /// Whether an event's crypto window is still live — i.e. its latest market end is in the
    /// future. Polymarket occasionally leaves dead ephemeral windows flagged `closed:false,
    /// active:true` (e.g. a 5-minute "Up or Down" event whose window ended months ago); opening
    /// one 400s the `/api/crypto/*` calls ("Timestamp too old for Chainlink API"). Events with
    /// no end date are kept — there's nothing to say they've expired.
    /// - Parameter event: The event to check.
    /// - Returns: `true` if the window hasn't ended yet (or has no end date).
    private func isWindowLive(_ event: Event) -> Bool {
        guard let latestEnd = event.markets.compactMap(\.endDate).max() else { return true }
        return latestEnd > now()
    }

    /// `classifiedEvents` filtered by `selectedSubTab`/`period`/`selectedTimeframe`/
    /// `searchQuery`, sorted by `sortOption`.
    public var visibleEvents: [(event: Event, kind: CryptoMarketKind)] {
        var events = classifiedEvents
        if let kind = selectedSubTab.kind {
            events = events.filter { $0.kind == kind }
        }
        if period != .all {
            events = events.filter { matches(period: period, title: $0.event.title) }
        }
        if selectedTimeframe != .all {
            events = events.filter { matches(timeframe: selectedTimeframe, recurrence: $0.event.recurrence) }
        }
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            events = events.filter { $0.event.title.localizedCaseInsensitiveContains(query) }
        }
        switch sortOption {
        case .volume24hr:
            events.sort { $0.event.volume24hr > $1.event.volume24hr }
        case .totalVolume:
            events.sort { $0.event.volume > $1.event.volume }
        case .liquidity:
            events.sort { $0.event.liquidity > $1.event.liquidity }
        case .newest:
            events.sort { newestSortKey($0.event) > newestSortKey($1.event) }
        case .endingSoon:
            events.sort { endingSoonSortKey($0.event) < endingSoonSortKey($1.event) }
        case .competitive:
            events.sort { competitiveSortKey($0.event) > competitiveSortKey($1.event) }
        }
        return events
    }

    /// The count of `classifiedEvents` (the already-`.other`-excluded set) matching a
    /// timeframe bucket, for the row's "{label} {count}" chips. `.all` counts everything.
    public func timeframeCount(for timeframe: Timeframe) -> Int {
        guard timeframe != .all else { return classifiedEvents.count }
        return classifiedEvents.filter { matches(timeframe: timeframe, recurrence: $0.event.recurrence) }.count
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

    /// Matches a timeframe bucket against an event's `recurrence` slug suffix (e.g.
    /// `"btc-up-or-down-5m"` → `.fiveMin`). `nil` recurrence or an unrecognized suffix
    /// (including `"-4h"`/`"-daily"`, which have no bucket in this row) never matches a
    /// specific bucket.
    private func matches(timeframe: Timeframe, recurrence: String?) -> Bool {
        guard let recurrence else { return false }
        switch timeframe {
        case .all: return true
        case .fiveMin: return recurrence.hasSuffix("-5m")
        case .fifteenMin: return recurrence.hasSuffix("-15m")
        case .hourly: return recurrence.hasSuffix("-hourly")
        }
    }

    /// The soonest market end date across an event's markets, for "Ending Soon" sort.
    /// Events with no end date on any market sort last.
    private func endingSoonSortKey(_ event: Event) -> Date {
        event.markets.compactMap(\.endDate).min() ?? .distantFuture
    }

    /// An event's creation date, for "Newest" sort. Events with no creation date sort last.
    private func newestSortKey(_ event: Event) -> Date {
        event.creationDate ?? .distantPast
    }

    /// An event's competitiveness score, for "Competitive" sort. Events with no score sort
    /// last (below the valid `0...1` range).
    private func competitiveSortKey(_ event: Event) -> Double {
        event.competitive ?? -1
    }
}
