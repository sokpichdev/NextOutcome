//
//  FetchCommentsUseCase.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

/// Loads the discussion comments for an event.
public struct FetchCommentsUseCase: Sendable {
    /// The market repository backing this use case.
    private let repository: MarketRepository

    /// Creates the use case.
    /// - Parameter repository: The market repository to fetch from.
    public init(repository: MarketRepository) {
        self.repository = repository
    }

    /// Fetches an event's comments.
    /// - Parameters:
    ///   - eventID: The event to fetch comments for.
    ///   - sort: How to order the comments. Defaults to newest first.
    ///   - holdersOnly: Restrict to commenters holding a position. Defaults to `false`.
    /// - Returns: The comments.
    public func execute(eventID: String, sort: CommentSort = .newest, holdersOnly: Bool = false) async throws -> [Comment] {
        try await repository.comments(eventID: eventID, sort: sort, holdersOnly: holdersOnly)
    }

    /// A stub instance (backed by an empty repository) for previews/tests.
    #if DEBUG
    public static let stub = FetchCommentsUseCase(repository: StubMarketRepository())
    #endif
}
