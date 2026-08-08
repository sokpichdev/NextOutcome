import Foundation
import MarketsDomain
import SharedDomain

/// The four inner tabs of an event's social strip.
public enum SocialTab: String, CaseIterable, Sendable {
    case comments, holders, positions, activity

    /// The tab's display title.
    public var title: String {
        switch self {
        case .comments: return "Comments"
        case .holders: return "Top Holders"
        case .positions: return "Positions"
        case .activity: return "Activity"
        }
    }
}

/// One selectable candidate/outcome market, for the Top Holders/Positions/Activity
/// per-candidate picker on multi-market events (e.g. each country in "World Cup Winner").
public struct SocialCandidate: Identifiable, Hashable, Sendable {
    /// The market id (also this candidate's identity).
    public let id: String
    /// The display label (the market's `groupItemTitle`, falling back to its question).
    public let title: String
    /// The market's condition id, used for holders/positions/activity lookups.
    public let conditionId: String
}

/// A minimum-trade-size filter option for the Activity tab.
public enum ActivityMinAmount: CaseIterable, Sendable {
    case none, ten, hundred, thousand, tenThousand, hundredThousand

    /// The menu label.
    public var title: String {
        switch self {
        case .none:            return "None"
        case .ten:              return "$10"
        case .hundred:          return "$100"
        case .thousand:         return "$1,000"
        case .tenThousand:      return "$10,000"
        case .hundredThousand:  return "$100,000"
        }
    }

    /// The USD threshold a trade's notional (`size * price`) must meet, or `nil` for no filter.
    public var threshold: Decimal? {
        switch self {
        case .none:             return nil
        case .ten:              return 10
        case .hundred:          return 100
        case .thousand:         return 1_000
        case .tenThousand:      return 10_000
        case .hundredThousand:  return 100_000
        }
    }
}

/// Drives the Comments · Top Holders · Positions · Activity strip below an event's rules.
/// Each tab fetches lazily, only on its first visit — `Positions` never fetches; it's a
/// static empty state (portfolio data arrives in a later release). Holders/Activity are
/// scoped to whichever candidate market is selected (see `candidates`/`selectedCandidateID`).
@MainActor
@Observable
public final class SocialStripViewModel {
    /// The currently-selected inner tab.
    public var selectedTab: SocialTab = .comments
    /// The comments tab's load state.
    public private(set) var commentsState: LoadState<[Comment]> = .idle
    /// The holders tab's load state.
    public private(set) var holdersState: LoadState<[Holder]> = .idle
    /// The activity tab's load state.
    public private(set) var activityState: LoadState<[ActivityTrade]> = .idle

    /// The comment sort order. Changing it resets and immediately re-fetches — the view's
    /// `.task(id: selectedTab)` only restarts on a *tab* change, so a filter change here
    /// must kick off its own reload rather than rely on that task to notice.
    public var commentSort: CommentSort = .newest {
        didSet {
            guard commentSort != oldValue else { return }
            commentsState = .idle
            Task { await loadIfNeeded(.comments) }
        }
    }
    /// Whether comments are restricted to commenters holding a position. See `commentSort`
    /// for why this reloads itself instead of waiting on the view's tab-keyed task.
    public var commentsHoldersOnly = false {
        didSet {
            guard commentsHoldersOnly != oldValue else { return }
            commentsState = .idle
            Task { await loadIfNeeded(.comments) }
        }
    }

    /// The selectable candidate markets (e.g. one per country), derived from `markets`.
    /// Empty when the event has a single market — the candidate picker hides itself then.
    public let candidates: [SocialCandidate]
    /// The selected candidate's id, or `nil` when there's only one market (no picker shown).
    public var selectedCandidateID: String? {
        didSet {
            guard selectedCandidateID != oldValue else { return }
            holdersState = .idle
            Task { await loadIfNeeded(.holders) }
        }
    }

    /// The condition id to use for holders: the selected candidate's, falling back to the
    /// event's top-market condition id (single-market events, or before selection).
    private var activeConditionId: String? {
        candidates.first { $0.id == selectedCandidateID }?.conditionId ?? conditionId
    }

    /// The Activity tab's own candidate selection, independent of Holders/Positions —
    /// `nil` means "All" (every candidate's trades, merged), which is Activity's default.
    public var selectedActivityCandidateID: String? {
        didSet {
            guard selectedActivityCandidateID != oldValue else { return }
            activityState = .idle
            Task { await loadIfNeeded(.activity) }
        }
    }

    /// The condition id(s) Activity should fetch: a single selected candidate, or every
    /// candidate's when "All" (`nil`) is selected — falling back to the event's top-market
    /// condition id for single-market events (no candidates to pick from).
    private var activityConditionIds: [String] {
        guard !candidates.isEmpty else { return conditionId.map { [$0] } ?? [] }
        if let selectedActivityCandidateID {
            return candidates.first { $0.id == selectedActivityCandidateID }.map { [$0.conditionId] } ?? []
        }
        return candidates.map(\.conditionId)
    }

    /// The Activity tab's minimum-trade-size filter.
    public var activityMinAmount: ActivityMinAmount = .none

    /// Activity trades after applying `activityMinAmount`, for the view to render.
    public var visibleActivityTrades: [ActivityTrade] {
        guard case .loaded(let trades) = activityState else { return [] }
        guard let threshold = activityMinAmount.threshold else { return trades }
        return trades.filter { $0.size * $0.price >= threshold }
    }

    /// The event whose comments are fetched.
    private let eventID: String
    /// The top market's condition id (for holders/activity); may be `nil`.
    private let conditionId: String?
    /// Use case that fetches comments.
    private let fetchComments: FetchCommentsUseCase
    /// Use case that fetches holders.
    private let fetchHolders: FetchHoldersUseCase
    /// Use case that fetches activity trades.
    private let fetchActivity: FetchActivityTradesUseCase
    /// Use case that fetches a commenter's positions in the event (the holder badge).
    private let fetchCommenterPositions: FetchCommenterPositionsUseCase
    /// The Activity tab's polling loop (stands in for a real-time feed — see `startActivityPolling`).
    private var activityPollTask: Task<Void, Never>?

    /// Creates the view model.
    /// - Parameters:
    ///   - eventID: The event whose comments to fetch.
    ///   - conditionId: The top market's condition for holders/activity, if any.
    ///   - markets: The event's markets, used to derive the candidate picker (`candidates`).
    ///     Events with 2+ markets get a picker; single-market events (or an empty list) don't.
    ///   - fetchComments: Comments use case.
    ///   - fetchHolders: Holders use case.
    ///   - fetchActivity: Activity-trades use case.
    ///   - fetchCommenterPositions: Commenter-holdings use case, for the comment badge.
    public init(
        eventID: String,
        conditionId: String?,
        markets: [Market] = [],
        fetchComments: FetchCommentsUseCase,
        fetchHolders: FetchHoldersUseCase,
        fetchActivity: FetchActivityTradesUseCase,
        fetchCommenterPositions: FetchCommenterPositionsUseCase
    ) {
        self.eventID = eventID
        self.conditionId = conditionId
        self.candidates = markets.count > 1
            ? markets.map { SocialCandidate(id: $0.id, title: $0.groupItemTitle ?? $0.question, conditionId: $0.conditionId) }
            : []
        self.fetchComments = fetchComments
        self.fetchHolders = fetchHolders
        self.fetchActivity = fetchActivity
        self.fetchCommenterPositions = fetchCommenterPositions
        self.selectedCandidateID = candidates.first?.id
    }

    /// Fetches `proxyWallet`'s positions in this event, for a comment row's holder badge.
    /// Best-effort: returns an empty array on failure (an anonymous/no-position commenter
    /// looks the same as a network hiccup — the badge simply doesn't show).
    public func commenterHoldings(proxyWallet: String) async -> [CommentHolding] {
        (try? await fetchCommenterPositions.execute(proxyWallet: proxyWallet, eventID: eventID)) ?? []
    }

    /// Resolves a holding's condition id to its candidate's display name (e.g. "France"),
    /// falling back to a shortened condition id when the market isn't in `candidates`
    /// (shouldn't normally happen — every holding comes from this event's own markets).
    public func candidateTitle(for holding: CommentHolding) -> String {
        candidates.first { $0.conditionId == holding.conditionId }?.title
            ?? String(holding.conditionId.suffix(6))
    }

    /// Fetches `tab`'s content if it hasn't already started loading. Safe to call every
    /// time a tab is shown — a view should call this from `.task(id: selectedTab)`.
    public func loadIfNeeded(_ tab: SocialTab) async {
        switch tab {
        case .comments:
            guard case .idle = commentsState else { return }
            commentsState = .loading
            do {
                let items = try await fetchComments.execute(eventID: eventID, sort: commentSort, holdersOnly: commentsHoldersOnly)
                commentsState = items.isEmpty ? .empty : .loaded(items)
            } catch {
                commentsState = isCancellation(error)
                    ? .idle
                    : .failed(message: "Couldn't load comments. Check your connection and try again.")
            }
        case .holders:
            guard case .idle = holdersState else { return }
            guard let activeConditionId, !activeConditionId.isEmpty else { holdersState = .empty; return }
            holdersState = .loading
            do {
                let items = try await fetchHolders.execute(conditionId: activeConditionId)
                holdersState = items.isEmpty ? .empty : .loaded(items)
            } catch {
                holdersState = isCancellation(error)
                    ? .idle
                    : .failed(message: "Couldn't load top holders. Check your connection and try again.")
            }
        case .positions:
            return // static empty-state; never fetches
        case .activity:
            guard case .idle = activityState else { return }
            let conditionIds = activityConditionIds
            guard !conditionIds.isEmpty else { activityState = .empty; return }
            activityState = .loading
            do {
                let items = try await fetchMergedActivity(conditionIds)
                activityState = items.isEmpty ? .empty : .loaded(items)
            } catch {
                activityState = isCancellation(error)
                    ? .idle
                    : .failed(message: "Couldn't load activity. Check your connection and try again.")
            }
        }
    }

    /// Fetches trades for one or more condition ids (bounded concurrency of 8 for "All"),
    /// merging and sorting the results newest-first, capped to the top 30.
    private func fetchMergedActivity(_ conditionIds: [String]) async throws -> [ActivityTrade] {
        guard conditionIds.count > 1 else {
            return try await fetchActivity.execute(conditionId: conditionIds[0])
        }
        let merged = try await withThrowingTaskGroup(of: [ActivityTrade].self) { group in
            var pending = conditionIds.makeIterator()
            var inFlight = 0
            var all: [ActivityTrade] = []

            func addNext() {
                guard let id = pending.next() else { return }
                inFlight += 1
                group.addTask { (try? await self.fetchActivity.execute(conditionId: id)) ?? [] }
            }
            for _ in 0..<8 { addNext() }
            while inFlight > 0 {
                guard let items = try await group.next() else { break }
                inFlight -= 1
                all += items
                addNext()
            }
            return all
        }
        return Array(merged.sorted { $0.timestamp > $1.timestamp }.prefix(30))
    }

    /// A cancelled fetch (e.g. from a `.task(id: selectedTab)` restart on rapid tab
    /// switching) is not a network failure — it must reset the tab to `.idle` so the
    /// next visit refetches, instead of showing a false "connection error" retry row.
    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if (error as? URLError)?.code == .cancelled { return true }
        return Task.isCancelled
    }

    /// Resets `tab`'s state to `.idle` and re-fetches. Used by the inline retry row.
    public func retry(_ tab: SocialTab) async {
        switch tab {
        case .comments: commentsState = .idle
        case .holders: holdersState = .idle
        case .activity: activityState = .idle
        case .positions: return
        }
        await loadIfNeeded(tab)
    }

    /// Starts a refresh-on-interval loop standing in for a real-time trades feed (no
    /// documented public WebSocket payload format was available to integrate against —
    /// see the Activity tab's follow-up note). Silently refreshes `activityState` every
    /// few seconds while the Activity tab is open; cancelled by `stopActivityPolling()`.
    public func startActivityPolling() {
        guard activityPollTask == nil else { return }
        activityPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled, let self else { return }
                let conditionIds = self.activityConditionIds
                guard !conditionIds.isEmpty else { continue }
                if let items = try? await self.fetchMergedActivity(conditionIds) {
                    self.activityState = items.isEmpty ? .empty : .loaded(items)
                }
            }
        }
    }

    /// Stops the Activity tab's polling loop (call from `.onDisappear`/tab change).
    public func stopActivityPolling() {
        activityPollTask?.cancel()
        activityPollTask = nil
    }
}
