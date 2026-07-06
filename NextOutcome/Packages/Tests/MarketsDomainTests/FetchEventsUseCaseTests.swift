import XCTest
import SharedDomain
@testable import MarketsDomain

final class FetchEventsUseCaseTests: XCTestCase {
    func test_execute_returnsPageFromRepository() async throws {
        let event = Event(
            id: "e1", title: "World Cup", slug: "world-cup",
            markets: [], volume: 5000, imageURL: nil
        )
        let repo = StubMarketRepository(eventsPage: Page(items: [event], nextCursor: "next"))
        let useCase = FetchEventsUseCase(repository: repo)

        let page = try await useCase.execute()

        XCTAssertEqual(page.items.count, 1)
        XCTAssertEqual(page.items.first?.id, "e1")
        XCTAssertEqual(page.nextCursor, "next")
    }
}

private final class StubMarketRepository: MarketRepository {
    let eventsPage: Page<Event>
    init(eventsPage: Page<Event>) { self.eventsPage = eventsPage }

    func fetchEvents(cursor: String?, tagID: String?, sort: EventSort, status: EventStatus, period: EventPeriod) async throws -> Page<Event> { eventsPage }
    func fetchMarkets(cursor: String?) async throws -> Page<Market> { Page(items: [], nextCursor: nil) }
    func fetchEvents(seriesID: String, status: EventStatus) async throws -> [Event] { [] }
    func fetchGameResults(eventIDs: [String]) async throws -> [String: GameResult] { [:] }
    func fetchEvent(slug: String) async throws -> Event { fatalError("unused") }
    func searchMarkets(query: String) async throws -> [Market] { [] }
    func fetchTags() async throws -> [Tag] { [] }
    func holders(conditionId: String) async throws -> [Holder] { [] }
    func comments(eventID: String, sort: CommentSort, holdersOnly: Bool) async throws -> [Comment] { [] }
    func trades(conditionId: String) async throws -> [ActivityTrade] { [] }
}
