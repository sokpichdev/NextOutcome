import XCTest
import Networking
import TradingDomain
@testable import TradingData

final class GeoblockClientTests: XCTestCase {
    private func makeClient(_ transport: MockTransport) -> GeoblockClient {
        GeoblockClient(client: APIClient(transport: transport, retry: .none))
    }

    func test_status_hitsPolymarketsPublicEndpoint() async throws {
        let transport = MockTransport()
        transport.stubbedData = Data(#"{"blocked":false}"#.utf8)

        _ = try await makeClient(transport).status()

        let url = try XCTUnwrap(transport.capturedRequests.first?.url)
        // The gate reads polymarket.com directly, not Gamma/CLOB — a wrong host here
        // would silently resolve "not blocked" for everyone.
        XCTAssertEqual(url.host, "polymarket.com")
        XCTAssertEqual(url.path, "/api/geoblock")
    }

    func test_status_mapsBlockedRegion() async throws {
        let transport = MockTransport()
        transport.stubbedData = Data(#"{"blocked":true,"closeOnly":false,"region":"US"}"#.utf8)

        let status = try await makeClient(transport).status()

        XCTAssertTrue(status.blocked)
        XCTAssertFalse(status.closeOnly)
        XCTAssertEqual(status.region, "US")
    }

    func test_status_mapsCloseOnly() async throws {
        let transport = MockTransport()
        transport.stubbedData = Data(#"{"closeOnly":true,"region":"FR"}"#.utf8)

        let status = try await makeClient(transport).status()

        XCTAssertFalse(status.blocked)
        XCTAssertTrue(status.closeOnly)
    }

    /// An empty body must mean "not blocked", never a decode failure — the view model
    /// treats a throw as "keep the last answer", so a crash here would be invisible.
    func test_status_emptyBodyDefaultsToNotBlocked() async throws {
        let transport = MockTransport()
        transport.stubbedData = Data("{}".utf8)

        let status = try await makeClient(transport).status()

        XCTAssertFalse(status.blocked)
        XCTAssertFalse(status.closeOnly)
        XCTAssertNil(status.region)
    }

    func test_status_propagatesTransportFailure() async {
        let transport = MockTransport()
        transport.stubbedStatus = 500
        transport.stubbedData = Data("{}".utf8)

        do {
            _ = try await makeClient(transport).status()
            XCTFail("expected the 500 to surface")
        } catch {
            // The view model turns this into "keep the last known access".
        }
    }
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
