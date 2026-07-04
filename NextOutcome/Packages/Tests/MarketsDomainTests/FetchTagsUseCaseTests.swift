import XCTest
import SharedDomain
@testable import MarketsDomain

final class FetchTagsUseCaseTests: XCTestCase {
    func test_execute_returnsTagsFromRepository() async throws {
        let tags = [
            Tag(id: "1", label: "Politics", slug: "politics"),
            Tag(id: "2", label: "Sports", slug: "sports"),
        ]
        let repo = StubMarketRepository(tags: tags)
        let useCase = FetchTagsUseCase(repository: repo)

        let result = try await useCase.execute()

        XCTAssertEqual(result.map(\.id), ["1", "2"])
        XCTAssertEqual(result.first?.label, "Politics")
    }
}

private final class StubMarketRepository: MarketRepository {
    let tags: [Tag]
    init(tags: [Tag]) { self.tags = tags }

    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus) async throws -> Page<Event> { Page(items: [], nextCursor: nil) }
    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] { [] }
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] { [:] }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> { Page(items: [], nextCursor: nil) }
    func fetchEvent(slug: String) async throws -> Event { fatalError("unused") }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func fetchTags() async throws -> [Tag] { tags }
    func holders(conditionId: String) async throws -> [Holder] { [] }
    func comments(eventID: String) async throws -> [Comment] { [] }
    func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
}
