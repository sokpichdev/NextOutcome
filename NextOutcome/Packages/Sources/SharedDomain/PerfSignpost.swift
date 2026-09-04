//
//  PerfSignpost.swift
//  NextOutcome
//
//  Created by Sok Pich on 20/08/2026.
//

import os

/// Signpost instrumentation for the hot paths called out in the performance audit, so a
/// claim like "this re-filters the whole feed on every render" is settled by a trace
/// rather than by reading the code.
///
/// **These ship in Release builds, deliberately.** Signposts are designed for exactly
/// this: when Instruments isn't recording, `OSSignposter` short-circuits on a single
/// boolean check and emits nothing. Profiling has to happen in a Release configuration —
/// Debug is `-Onone` and misrepresents Swift's ARC and generics traffic badly enough to
/// send you chasing costs that don't exist in production — so instrumentation compiled
/// out of Release would be instrumentation you can never use.
///
/// To view: Instruments → **os_signpost**, filtered to the `com.nextoutcome.perf`
/// subsystem. Each interval reports its own count and duration, which is the number that
/// matters here — these paths are cheap individually and ruinous by repetition.
///
/// See `docs/performance/baselines.md` for the recording protocol.
public enum Perf {
    /// The subsystem every signpost in the app is filed under. Type this into
    /// Instruments' subsystem filter to isolate our signposts from the system's.
    public static let subsystem = "com.nextoutcome.perf"

    /// Work that runs inside a SwiftUI body evaluation, where the cost is paid per frame
    /// and per visible row rather than once per user action.
    ///
    /// - Important: Intervals use `OSSignpostID.exclusive`, which requires that no two
    ///   intervals *of the same name* overlap. Every current call site is a synchronous,
    ///   non-reentrant `@MainActor` computation, so this holds. Nesting intervals with
    ///   *different* names is fine and is how the ledger reads today — the
    ///   `HomeCardKind.isSports`/`isCrypto` calls inside `EventList.visibleEvents` show up
    ///   as time attributed to the outer interval. If a signposted path ever becomes
    ///   concurrent, give it its own `makeSignpostID()` instead.
    public static let renderPath = OSSignposter(subsystem: subsystem, category: "RenderPath")

    // MARK: - Interval names
    //
    // Kept here rather than inline at the call sites so the set of things being measured
    // is enumerable in one place, and so the strings in a saved trace match the strings
    // you can grep for.

    /// `EventListViewModel.visibleEvents` — the Home feed's filter/pin pipeline (audit #05).
    public static let visibleEventsHome: StaticString = "EventList.visibleEvents"
    /// `CryptoHubViewModel.visibleEvents` — the Crypto hub's five-filter chain plus sort (audit #05).
    public static let visibleEventsCrypto: StaticString = "CryptoHub.visibleEvents"
    /// `HomeCardKind.classify` — per-card variant classification (audit #03).
    public static let classifyCard: StaticString = "HomeCardKind.classify"
}

public extension OSSignposter {
    /// Times `body` as a signpost interval.
    ///
    /// Use this for expression-shaped work. For a long computed property with several early
    /// returns, prefer `beginInterval`/`defer endInterval` directly — it keeps the diff to
    /// two lines and avoids re-indenting the body.
    /// - Parameters:
    ///   - name: The interval name; must be one of `Perf`'s constants so traces stay greppable.
    ///   - body: The work to time.
    /// - Returns: Whatever `body` returns.
    @inlinable
    func measure<T>(_ name: StaticString, _ body: () throws -> T) rethrows -> T {
        let state = beginInterval(name)
        defer { endInterval(name, state) }
        return try body()
    }
}
