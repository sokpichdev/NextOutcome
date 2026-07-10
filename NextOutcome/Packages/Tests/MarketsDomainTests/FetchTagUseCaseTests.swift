import XCTest
import SharedDomain
@testable import MarketsDomain

final class FetchTagUseCaseTests: XCTestCase {
    func test_execute_returnsTagFromRepository() async throws {
        let repo = StubMarketRepository(tag: Tag(id: "21", label: "Crypto", slug: "crypto"))
        let useCase = FetchTagUseCase(repository: repo)

        let result = try await useCase.execute(slug: "crypto")

        XCTAssertEqual(result?.id, "21")
    }

    func test_execute_defaultRepositoryImplementation_returnsNil() async throws {
        // A repository that doesn't override fetchTag(slug:) (the extension default)
        // should resolve to nil rather than throwing, so callers can treat "not
        // implemented" and "not found" the same way.
        let repo = DefaultOnlyMarketRepository()
        let useCase = FetchTagUseCase(repository: repo)

        let result = try await useCase.execute(slug: "anything")

        XCTAssertNil(result)
    }
}

private final class StubMarketRepository: MarketRepository {
    let tag: Tag
    init(tag: Tag) { self.tag = tag }

    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> { Page(items: [], nextCursor: nil) }
    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] { [] }
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] { [:] }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> { Page(items: [], nextCursor: nil) }
    func fetchEvent(slug: String) async throws -> Event { fatalError("unused") }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func fetchTags() async throws -> [Tag] { [] }
    func holders(conditionId: String) async throws -> [Holder] { [] }
    func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment] { [] }
    func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
    func fetchTag(slug: String) async throws -> Tag? { tag }
}

/// Conforms to `MarketRepository` without touching `fetchTag(slug:)` at all, to prove the
/// protocol extension's default (`nil`) is what runs.
private final class DefaultOnlyMarketRepository: MarketRepository {
    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> { Page(items: [], nextCursor: nil) }
    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] { [] }
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] { [:] }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> { Page(items: [], nextCursor: nil) }
    func fetchEvent(slug: String) async throws -> Event { fatalError("unused") }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func fetchTags() async throws -> [Tag] { [] }
    func holders(conditionId: String) async throws -> [Holder] { [] }
    func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment] { [] }
    func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
}
