//
//  EndpointQueryTests.swift
//  NextOutcome
//
//  Created by Sok Pich on 16/08/2026.
//

import XCTest
@testable import Networking

/// URL building, and specifically the repeated-key case a dictionary cannot express.
final class EndpointQueryTests: XCTestCase {
    private func items(_ endpoint: Endpoint) -> [URLQueryItem] {
        guard let url = endpoint.urlRequest?.url,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return [] }
        return components.queryItems ?? []
    }

    func test_dictionaryQueryStillBuildsAsBefore() {
        let endpoint = Endpoint(host: .gamma, path: "/events", query: ["closed": "false"])

        XCTAssertEqual(items(endpoint), [URLQueryItem(name: "closed", value: "false")])
    }

    func test_extraItemsCanRepeatAKeyTheDictionaryAlreadyHolds() {
        // Gamma ANDs tags by repeating `tag_id`, which a [String: String] cannot express —
        // asking for games *and* soccer needs tag_id twice plus tag_match=all.
        let endpoint = Endpoint(
            host: .gamma, path: "/events/keyset",
            query: ["tag_id": "100639", "tag_match": "all"],
            extraQueryItems: [URLQueryItem(name: "tag_id", value: "100350")]
        )

        let tagIDs = items(endpoint).filter { $0.name == "tag_id" }.compactMap(\.value).sorted()
        XCTAssertEqual(tagIDs, ["100350", "100639"])
        XCTAssertTrue(items(endpoint).contains(URLQueryItem(name: "tag_match", value: "all")))
    }

    func test_extraItemsDefaultToNoneAndLeaveTheURLUnchanged() {
        let endpoint = Endpoint(host: .gamma, path: "/events", query: [:])

        XCTAssertEqual(endpoint.urlRequest?.url?.absoluteString, "https://\(PolymarketService.gamma.baseURL)/events")
    }
}
