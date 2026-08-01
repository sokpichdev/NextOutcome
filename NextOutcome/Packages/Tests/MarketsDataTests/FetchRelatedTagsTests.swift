//
//  FetchRelatedTagsTests.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/08/2026.
//

import XCTest
import Networking
@testable import MarketsData
import MarketsDomain

final class FetchRelatedTagsTests: XCTestCase {
    /// A trimmed copy of a real `/related-tags/tags` payload, including a dead tag.
    private let payload = Data("""
    [{"id":"100215","label":"All","slug":"all","forceShow":false,"activeEventsCount":2},
     {"id":"2","label":"Politics","slug":"politics","forceHide":true,"activeEventsCount":1556},
     {"id":"999","label":"June 27","slug":"may30","activeEventsCount":0}]
    """.utf8)

    private func makeRepository(
        transport: MockTransport,
        cache: RelatedTagsCache = RelatedTagsCache()
    ) -> GammaMarketRepository {
        GammaMarketRepository(client: APIClient(transport: transport, retry: .none),
                              relatedTagsCache: cache)
    }

    func test_fetchRelatedTags_hitsTheHydratedEndpoint() async throws {
        let transport = MockTransport()
        transport.stubbedData = payload

        _ = try await makeRepository(transport: transport).fetchRelatedTags(slug: "top-navbar")

        let url = try XCTUnwrap(transport.capturedRequests.first?.url)
        XCTAssertEqual(url.host, "gamma-api.polymarket.com")
        // The trailing `/tags` is the whole difference between bare relationship records
        // (tagID/relatedTagID/rank) and renderable tag objects.
        XCTAssertEqual(url.path, "/tags/slug/top-navbar/related-tags/tags")
        XCTAssertEqual(url.query, "status=active")
    }

    func test_fetchRelatedTags_decodesActiveEventsCount() async throws {
        let transport = MockTransport()
        transport.stubbedData = payload

        let tags = try await makeRepository(transport: transport).fetchRelatedTags(slug: "all")

        XCTAssertEqual(tags.map(\.slug), ["all", "politics", "may30"])
        XCTAssertEqual(tags.map(\.activeEventsCount), [2, 1556, 0])
        // The repository returns the raw row; dropping dead tags is the use case's job.
        XCTAssertEqual(tags.count, 3)
    }

    func test_fetchRelatedTags_emptyRowDecodesCleanly() async throws {
        let transport = MockTransport()
        transport.stubbedData = Data("[]".utf8)

        let tags = try await makeRepository(transport: transport).fetchRelatedTags(slug: "elections")

        XCTAssertTrue(tags.isEmpty)
    }

    func test_fetchRelatedTags_servesSecondCallFromCache() async throws {
        let transport = MockTransport()
        transport.stubbedData = payload
        let repository = makeRepository(transport: transport)

        _ = try await repository.fetchRelatedTags(slug: "all")
        _ = try await repository.fetchRelatedTags(slug: "all")

        XCTAssertEqual(transport.capturedRequests.count, 1)
    }

    func test_fetchRelatedTags_cachesPerSlug() async throws {
        let transport = MockTransport()
        transport.stubbedData = payload
        let repository = makeRepository(transport: transport)

        _ = try await repository.fetchRelatedTags(slug: "all")
        _ = try await repository.fetchRelatedTags(slug: "politics")

        XCTAssertEqual(transport.capturedRequests.count, 2)
    }

    func test_fetchRelatedTags_refetchesAfterTTLExpires() async throws {
        let transport = MockTransport()
        transport.stubbedData = payload
        let clock = TestClock()
        let repository = makeRepository(
            transport: transport,
            cache: RelatedTagsCache(ttl: 3600, now: { clock.now })
        )

        _ = try await repository.fetchRelatedTags(slug: "all")
        clock.advance(by: 3601)
        _ = try await repository.fetchRelatedTags(slug: "all")

        XCTAssertEqual(transport.capturedRequests.count, 2)
    }
}

/// A settable clock so TTL tests don't sleep.
private final class TestClock: @unchecked Sendable {
    var now = Date(timeIntervalSince1970: 0)
    func advance(by seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

private final class MockTransport: HTTPTransport, @unchecked Sendable {
    var stubbedData = Data()
    var stubbedStatus = 200
    var capturedRequests: [URLRequest] = []

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        capturedRequests.append(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: stubbedStatus,
                                       httpVersion: nil, headerFields: nil)!
        return (stubbedData, response)
    }
}
