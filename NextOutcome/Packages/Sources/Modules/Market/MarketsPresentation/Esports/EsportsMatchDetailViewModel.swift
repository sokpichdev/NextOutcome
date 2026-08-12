//
//  EsportsMatchDetailViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 10/08/2026.
//

import Foundation
import MarketsDomain
import LiveStatsDomain

/// Drives the Esports match detail screen: the scoreboard's live score, the market sections'
/// prices, and the Livestream tab's broadcast.
///
/// Seeded rather than fetched cold. The hub pushes a complete `Event` — markets, and (since
/// Gamma ships them on the event payload) the score, period and teams too — so the screen
/// paints a full scoreboard on its first frame. Everything after that is refresh:
///
/// - the socket (`SportsStateStreaming`) pushes score/period the instant they change,
/// - the `/events/results` poll backstops it and supplies team logos/colours,
/// - re-fetching the event picks up prices and map markets settling over a 60–90 minute series.
@MainActor
@Observable
public final class EsportsMatchDetailViewModel {
    // No load state: the pushed event is always renderable, so there is nothing to show a
    // spinner or an error screen for. Refresh failures leave the last good content in place.

    /// The event, refreshed in place as markets settle.
    public private(set) var event: Event
    /// The latest live/final result.
    public private(set) var result: GameResult?
    /// The broadcast to embed, once resolved. `nil` shows artwork.
    public private(set) var stream: EsportsStream?
    /// The match's game, for the status line's caption.
    public private(set) var league: EsportsLeague?

    /// Re-fetches the event as its markets settle.
    private let fetchEvent: FetchEventUseCase
    /// Loads the live score.
    private let fetchGameResults: FetchGameResultsUseCase
    /// Confirms a broadcast is on air before embedding it. `nil` disables probing.
    private let liveStreamProber: (any LiveStreamProbing)?
    /// Pushes instant score updates. `nil` leaves the poll as the only source.
    private let streamer: (any SportsStateStreaming)?
    /// Injectable clock for deterministic tests.
    private let now: () -> Date
    /// Seconds between refreshes while the screen is open.
    private let pollInterval: TimeInterval

    /// The refresh loop, while the screen is visible.
    private var pollTask: Task<Void, Never>?
    /// The socket subscription, while the screen is visible.
    private var socketTask: Task<Void, Never>?
    /// Whether the user has opened the Livestream tab, which is what earns a probe.
    private var hasRequestedStream = false

    /// Creates the view model.
    /// - Parameters:
    ///   - event: The event pushed from the hub, used as the initial content.
    ///   - fetchEvent: Re-fetches the event by slug.
    ///   - fetchGameResults: Loads the live score.
    ///   - league: The match's game, resolved by the hub against its catalogue.
    ///   - liveStreamProber: Confirms the broadcast is on air. Defaults to `nil` (no probing),
    ///     keeping tests and previews network-free.
    ///   - streamer: The sports websocket. Defaults to `nil` (poll-only).
    ///   - now: Supplies the current time. Defaults to `Date()`.
    ///   - pollInterval: Seconds between refreshes. Defaults to 20.
    public init(
        event: Event,
        fetchEvent: FetchEventUseCase,
        fetchGameResults: FetchGameResultsUseCase,
        league: EsportsLeague? = nil,
        liveStreamProber: (any LiveStreamProbing)? = nil,
        streamer: (any SportsStateStreaming)? = nil,
        now: @escaping () -> Date = { Date() },
        pollInterval: TimeInterval = 20
    ) {
        self.event = event
        self.fetchEvent = fetchEvent
        self.fetchGameResults = fetchGameResults
        self.league = league
        self.liveStreamProber = liveStreamProber
        self.streamer = streamer
        self.now = now
        self.pollInterval = pollInterval
        // The event payload carries the score Gamma already knows, so the scoreboard is
        // populated before a single request goes out.
        self.result = event.initialResult
    }

    // MARK: - Derived

    /// The match's display-ready teams, title and moneyline prices. Internal because
    /// `EsportsMatchInfo` is — only this module's views read it.
    var info: EsportsMatchInfo { EsportsMatchInfo(event: event, result: result, league: league) }

    /// The scoreboard model.
    var scoreboard: EsportsScoreboardBuilder.Model {
        EsportsScoreboardBuilder.build(event: event, result: result, league: league)
    }

    /// The event's markets grouped into sections.
    var groups: [(group: MarketGroup, markets: [Market])] {
        MarketGroupClassifier.groups(for: event.markets)
    }

    /// Whether the match is being played right now.
    public var isLive: Bool { result?.live == true }

    /// Whether the match has finished.
    public var hasEnded: Bool { result?.ended == true }

    /// The status line's lead text: how far through the series the match is, "Final" once
    /// it's over, or the kickoff time before it starts.
    ///
    /// Deliberately never a countdown against `gameStartTime`: every market on a live match
    /// carries a start time in the past, which is how the generic event screen came to print
    /// "Ended" over a match that was still being played.
    public var statusText: String? {
        if hasEnded { return "Final" }
        if let progress = EsportsMatchProgress.parse(result?.period) {
            return "Map \(progress.currentMap) of \(progress.totalMaps)"
        }
        if isLive { return "Live" }
        guard let start = event.gameStartTime else { return nil }
        return start.formatted(date: .omitted, time: .shortened)
    }

    /// The series moneyline — the market whose two outcomes are the teams. Charted as two
    /// lines and used for the header prices.
    public var moneylineMarket: Market? { info.moneyline }

    // MARK: - Lifecycle

    /// Starts the refresh loop and the socket subscription. Safe to call repeatedly.
    public func start() {
        subscribeToSocket()
        guard pollTask == nil else { return }
        let nanoseconds = UInt64(pollInterval * 1_000_000_000)
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled, let self else { return }
                await self.refresh()
            }
        }
    }

    /// Stops the refresh loop and closes the socket (call from `.onDisappear`).
    public func stop() {
        pollTask?.cancel()
        pollTask = nil
        socketTask?.cancel()
        socketTask = nil
    }

    /// Whether the refresh loop is running (exposed for tests).
    public var isPolling: Bool { pollTask != nil }

    /// Re-fetches the result and the event, then re-resolves the broadcast.
    ///
    /// A failed event re-fetch is deliberately not an error: the seeded event is still
    /// perfectly renderable, and blanking a working screen over a refresh that will retry in
    /// twenty seconds would be the wrong trade.
    public func refresh() async {
        await refreshResult()
        if let refreshed = try? await fetchEvent.execute(slug: event.slug) {
            event = refreshed
        }
        await refreshStream()
    }

    /// Loads the live score. Stops the loop once the match is over — a finished match has
    /// nothing left to poll for.
    private func refreshResult() async {
        guard let fetched = try? await fetchGameResults.execute(eventIDs: [event.id]),
              let latest = fetched[event.id]
        else { return }
        result = latest
        if latest.ended {
            pollTask?.cancel()
            pollTask = nil
            socketTask?.cancel()
            socketTask = nil
        }
    }

    // MARK: - Broadcast

    /// Called when the user opens the Livestream tab. Probing costs a page fetch, so nobody
    /// pays for it until they ask to watch.
    public func requestStream() async {
        hasRequestedStream = true
        await refreshStream()
    }

    /// The broadcast URL, for the "Open broadcast" fallback on hosts we can't embed.
    public var broadcastURL: URL? {
        guard let source = event.resolutionSource, !source.isEmpty else { return nil }
        return URL(string: source)
    }

    /// Resolves the broadcast, on the same two tiers the hub uses: a URL that names its own
    /// video needs no network, and only otherwise do we spend a probe.
    private func refreshStream() async {
        guard hasRequestedStream else { return }
        guard let source = event.resolutionSource, !source.isEmpty else {
            stream = nil
            return
        }
        if isLive, let embeddable = EsportsStream.embeddable(from: source) {
            stream = embeddable
            return
        }
        stream = await liveStreamProber?.liveStream(for: source)
    }

    // MARK: - Socket

    /// Opens the score subscription, keyed on the feed's own `gameID`. Skipped when the match
    /// has no feed id (the poll covers it) or has already finished.
    private func subscribeToSocket() {
        guard socketTask == nil, !hasEnded,
              let streamer, let gameID = event.gameID, !gameID.isEmpty
        else { return }
        socketTask = Task { [weak self] in
            guard let stream = self?.nonisolatedStates(streamer: streamer, gameID: gameID) else { return }
            do {
                for try await snapshot in stream {
                    guard !Task.isCancelled, let self else { return }
                    self.apply(snapshot: snapshot)
                }
            } catch {}
        }
    }

    /// Opens the stream outside the actor hop, keeping `subscribeToSocket` synchronous.
    nonisolated private func nonisolatedStates(
        streamer: any SportsStateStreaming, gameID: String
    ) -> AsyncThrowingStream<MatchState, Error> {
        streamer.states(gameID: gameID)
    }

    /// Merges a socket snapshot into `result`, keeping the poll-supplied team metadata
    /// (logos, colours, ordering) that the socket doesn't carry.
    private func apply(snapshot: MatchState) {
        let existing = result
        let updated = GameResult(
            eventID: event.id,
            score: snapshot.rawScore ?? existing?.score,
            elapsed: existing?.elapsed,
            period: snapshot.period ?? existing?.period,
            live: snapshot.isLive,
            ended: snapshot.ended,
            teams: existing?.teams ?? []
        )
        guard updated != existing else { return }
        result = updated
    }
}
