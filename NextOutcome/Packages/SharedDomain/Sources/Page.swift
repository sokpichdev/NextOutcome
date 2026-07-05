//
//  Page.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

/// A single page of paginated results, used whenever a repository or use case fetches
/// data from an API that supports cursor-based pagination (e.g. "load more" lists).
///
/// This is intentionally generic over `T` so it can wrap any item type (markets,
/// activity entries, leaderboard rows, etc.) rather than each feature defining its
/// own pagination wrapper.
public struct Page<T> {
    /// The items returned for this page. May be empty if there are no more results.
    public let items: [T]

    /// The cursor to pass into the next fetch request to get the following page.
    /// `nil` means there is no next page — the caller has reached the end of the list.
    public let nextCursor: String?

    /// Creates a page of results.
    /// - Parameters:
    ///   - items: The items belonging to this page.
    ///   - nextCursor: The cursor for fetching the next page, or `nil` if this is the last page.
    public init(items: [T], nextCursor: String?) {
        self.items = items
        self.nextCursor = nextCursor
    }
}
