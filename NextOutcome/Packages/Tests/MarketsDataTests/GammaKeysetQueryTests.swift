import XCTest
@testable import MarketsData
import MarketsDomain

/// The cursor-paged feed query. Keyset is what the Polymarket web client uses; offset paging
/// over a continuously-changing `volume24hr` sort duplicates and drops rows between pages.
final class GammaKeysetQueryTests: XCTestCase {
    /// Keyset endpoints reject `offset` with HTTP 422 — it must never be sent, on any page.
    func test_neverSendsOffset() {
        XCTAssertNil(GammaEventQuery.keysetParams(cursor: nil, tagID: nil, sort: .volume24h, status: .active)["offset"])
        XCTAssertNil(GammaEventQuery.keysetParams(cursor: "abc", tagID: nil, sort: .volume24h, status: .active)["offset"])
    }

    /// The first page carries no cursor at all.
    func test_firstPage_omitsCursor() {
        let params = GammaEventQuery.keysetParams(cursor: nil, tagID: nil, sort: .volume24h, status: .active)
        XCTAssertNil(params["after_cursor"])
        XCTAssertEqual(params["limit"], "20")
    }

    /// Subsequent pages pass the previous page's opaque cursor straight through.
    func test_subsequentPage_sendsAfterCursor() {
        let cursor = "N-BHqeH5Tvkij6p-dcU1GRJcCefzWdNlpxeJbOutkoh7Ino"
        let params = GammaEventQuery.keysetParams(cursor: cursor, tagID: nil, sort: .volume24h, status: .active)
        XCTAssertEqual(params["after_cursor"], cursor)
    }

    /// An empty-string cursor is not a cursor — sending `after_cursor=` would be a bad request.
    func test_emptyCursor_isTreatedAsFirstPage() {
        XCTAssertNil(GammaEventQuery.keysetParams(cursor: "", tagID: nil, sort: .volume24h, status: .active)["after_cursor"])
    }

    /// Filters and sort must behave identically to the offset shape — only paging changed.
    func test_filtersMatchTheOffsetShape() {
        let keyset = GammaEventQuery.keysetParams(cursor: nil, tagID: "2", sort: .endingSoon, status: .resolved)
        let offset = GammaEventQuery.params(offset: 0, tagID: "2", sort: .endingSoon, status: .resolved)
        for key in ["order", "ascending", "closed", "active", "tag_id"] {
            XCTAssertEqual(keyset[key], offset[key], "param '\(key)' diverged between the two shapes")
        }
    }

    /// The feed page size matches the web client's.
    func test_pageSizeMatchesWebClient() {
        XCTAssertEqual(GammaEventQuery.keysetParams(cursor: nil, tagID: nil, sort: .volume24h, status: .active)["limit"], "20")
    }
}
