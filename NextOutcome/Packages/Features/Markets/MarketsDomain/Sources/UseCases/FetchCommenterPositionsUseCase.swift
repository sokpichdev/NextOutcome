//
//  FetchCommenterPositionsUseCase.swift
//  NextOutcome
//

/// Loads a commenter's positions in an event, for the comment "holder" badge.
public struct FetchCommenterPositionsUseCase: Sendable {
    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to fetch from.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Fetches a commenter's positions in an event.
    /// - Parameters:
    ///   - proxyWallet: The commenter's proxy (trading) wallet.
    ///   - eventID: The event to scope positions to.
    /// - Returns: The commenter's holdings in the event.
    public func execute(proxyWallet: String, eventID: String) async throws -> [CommentHolding] {
        try await repository.commenterPositions(proxyWallet: proxyWallet, eventID: eventID)
    }

    /// A stub instance (backed by an empty repository) for previews/tests.
    #if DEBUG
    public static let stub = FetchCommenterPositionsUseCase(repository: StubMarketRepository())
    #endif
}
