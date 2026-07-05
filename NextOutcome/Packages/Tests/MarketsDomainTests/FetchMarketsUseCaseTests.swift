import XCTest
import SharedDomain
@testable import MarketsDomain

final class FetchMarketsUseCaseTests: XCTestCase {
    func test_execute_returnsPageFromRepository() async throws {
        let market = Market(
            id: "1", question: "Will X happen?", slug: "will-x",
            outcomes: [], volume: 1000, liquidity: 500,
            endDate: nil, isResolved: false, imageURL: nil
        )
        let repo = MockMarketRepository(page: Page(items: [market], nextCursor: nil))
        let useCase = FetchMarketsUseCase(repository: repo)

        let page = try await useCase.execute()

        XCTAssertEqual(page.items.count, 1)
        XCTAssertEqual(page.items.first?.id, "1")
    }
}

private final class MockMarketRepository: MarketRepository {
    let page: Page<Market>
    init(page: Page<Market>) { self.page = page }
    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> { Page(items: [], nextCursor: nil) }
    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] { [] }
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] { [:] }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> { page }
    func fetchEvent(slug: String) async throws -> Event { fatalError() }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func fetchTags() async throws -> [Tag] { [] }
    func holders(conditionId: String) async throws -> [Holder] { [] }
    func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment] { [] }
    func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
}
