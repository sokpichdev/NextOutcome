//
//  RelatedTagsCache.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/08/2026.
//

import Foundation
import MarketsDomain

/// A small time-to-live cache for the navigation rows, keyed by tag slug.
///
/// The two nav rows are fetched per category, so switching categories would otherwise issue a
/// request every time the user taps a chip. The rows are ops-curated and change on the order of
/// hours, so a one-hour TTL keeps the rail responsive without ever showing a stale menu for long.
///
/// Deliberately *not* a `URLCache` on the transport: that would change freshness semantics for
/// every endpoint in the app, whereas only the tag rows want this behaviour.
///
/// Concurrent misses on the same slug will each fetch — there's no in-flight request coalescing.
/// At this volume (one request per category, once an hour) that's not worth the extra machinery.
public actor RelatedTagsCache {
    /// A cached row plus the instant it was stored, so expiry is computed on read.
    private struct Entry {
        let tags: [Tag]
        let storedAt: Date
    }

    private var entries: [String: Entry] = [:]
    private let ttl: TimeInterval
    /// Injected clock. Tests advance time by swapping this rather than sleeping.
    private let now: @Sendable () -> Date

    /// Creates the cache.
    /// - Parameters:
    ///   - ttl: How long an entry stays fresh. Defaults to one hour.
    ///   - now: Supplies the current time; override in tests to exercise expiry.
    public init(ttl: TimeInterval = 3600, now: @escaping @Sendable () -> Date = { Date() }) {
        self.ttl = ttl
        self.now = now
    }

    /// The cached row for `slug`, or `nil` when absent or expired.
    ///
    /// An empty array is a real cached value, not a miss — several categories legitimately have
    /// no related tags, and re-requesting those on every selection is exactly what this avoids.
    public func value(for slug: String) -> [Tag]? {
        guard let entry = entries[slug] else { return nil }
        guard now().timeIntervalSince(entry.storedAt) < ttl else {
            entries[slug] = nil
            return nil
        }
        return entry.tags
    }

    /// Stores `tags` as the current row for `slug`, restarting its TTL.
    public func store(_ tags: [Tag], for slug: String) {
        entries[slug] = Entry(tags: tags, storedAt: now())
    }
}
