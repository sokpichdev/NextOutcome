//
//  FetchRelatedTagsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/08/2026.
//

/// Fetches one of the app's navigation rows.
///
/// Both category rows are the same query at different levels: a row is a curated tag whose
/// *related tags* are its entries. `execute(slug: "top-navbar")` returns the top-level category
/// rail; `execute(slug: "politics")` returns the sub-topic carousel shown under Politics.
public struct FetchRelatedTagsUseCase: Sendable {
    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to fetch from.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Returns the live tags related to `slug`, in the server's rank order.
    ///
    /// Tags with no live events are dropped here rather than in the UI: Gamma's `status`
    /// parameter is a no-op, so expired topics stay in the payload (the Crypto row still
    /// carries date tags like "June 27" at a count of zero) and would otherwise render as
    /// chips that lead to an empty feed. Filtering here is what makes the rows self-clean.
    ///
    /// An empty result is normal — several categories have no sub-topics at all.
    /// - Parameter slug: The row's tag slug, e.g. `"top-navbar"` or `"crypto"`.
    /// - Returns: The row's tags, rank-ordered, excluding dead ones.
    public func execute(slug: String) async throws -> [Tag] {
        try await repository.fetchRelatedTags(slug: slug)
            .filter { ($0.activeEventsCount ?? 0) > 0 }
    }

    /// Returns an instance whose `execute` always returns an empty row. Use in unit tests.
    #if DEBUG
    public static let stub = FetchRelatedTagsUseCase(repository: StubMarketRepository())
    #endif
}
