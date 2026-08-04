//
//  FeaturedEventsCache.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/08/2026.
//

import Foundation
import MarketsDomain

/// A single-slot time-to-live cache for Polymarket's curated featured list.
///
/// The featured row is editorial and changes on the order of hours, but it's requested on
/// every cold load of the feed. Polymarket's own web client caches it for five minutes
/// (`staleTime: 300_000` on the `discovery-pin` loader), so this matches that.
///
/// Sibling of `RelatedTagsCache` and deliberately separate rather than a shared generic:
/// the two have different TTLs and different keying (this one has no key at all), and
/// keeping them apart means changing one can't surprise the other.
///
/// Concurrent misses will each fetch — there's no in-flight coalescing. At one request per
/// five minutes that isn't worth the machinery.
public actor FeaturedEventsCache {
    /// The cached list plus the instant it was stored, so expiry is computed on read.
    private struct Entry {
        let events: [Event]
        let storedAt: Date
    }

    private var entry: Entry?
    private let ttl: TimeInterval
    /// Injected clock. Tests advance time by swapping this rather than sleeping.
    private let now: @Sendable () -> Date

    /// Creates the cache.
    /// - Parameters:
    ///   - ttl: How long the list stays fresh. Defaults to five minutes, matching the web.
    ///   - now: Supplies the current time; override in tests to exercise expiry.
    public init(ttl: TimeInterval = 300, now: @escaping @Sendable () -> Date = { Date() }) {
        self.ttl = ttl
        self.now = now
    }

    /// The cached list, or `nil` when absent or expired.
    ///
    /// An empty array is a real cached value, not a miss: if Gamma returns no featured
    /// events, re-asking on every load is exactly what this avoids.
    public func value() -> [Event]? {
        guard let entry else { return nil }
        guard now().timeIntervalSince(entry.storedAt) < ttl else {
            self.entry = nil
            return nil
        }
        return entry.events
    }

    /// Stores `events` as the current featured list, restarting the TTL.
    public func store(_ events: [Event]) {
        entry = Entry(events: events, storedAt: now())
    }
}
