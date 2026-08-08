//
//  FetchTagUseCase.swift
//  NextOutcome
//

/// Resolves a single tag by its URL slug — used to look up a curated home-rail
/// category's live Gamma tag id at runtime (e.g. "crypto" -> id "21").
public struct FetchTagUseCase: Sendable {
    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to fetch from.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Resolves `slug` to a tag, or `nil` if it doesn't exist or the lookup fails.
    /// - Parameter slug: The tag's URL slug, e.g. `"crypto"`.
    /// - Returns: The matching tag, or `nil`.
    public func execute(slug: String) async throws -> Tag? {
        try await repository.fetchTag(slug: slug)
    }

    /// Returns an instance whose `execute` always returns `nil`. Use in unit tests.
    #if DEBUG
    public static let stub = FetchTagUseCase(repository: StubMarketRepository())
    #endif
}
