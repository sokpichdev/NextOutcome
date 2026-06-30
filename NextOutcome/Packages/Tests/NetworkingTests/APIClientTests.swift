import XCTest
@testable import Networking

final class APIClientTests: XCTestCase {
    func test_fetch_decodesSuccessfulResponse() async throws {
        let transport = MockTransport()
        transport.stubbedData = #"{"value": 42}"#.data(using: .utf8)!
        let client = APIClient(transport: transport, retry: .none)

        struct Payload: Decodable { let value: Int }
        let endpoint = Endpoint(host: .gamma, path: "/test")
        let result: Payload = try await client.fetch(endpoint)

        XCTAssertEqual(result.value, 42)
    }

    func test_fetch_throwsHTTPError_on4xx() async throws {
        let transport = MockTransport()
        transport.stubbedStatus = 404
        transport.stubbedData = Data()
        let client = APIClient(transport: transport, retry: .none)

        let endpoint = Endpoint(host: .gamma, path: "/test")
        do {
            let _: EmptyResponse = try await client.fetch(endpoint)
            XCTFail("Expected error")
        } catch APIError.http(let status, _) {
            XCTAssertEqual(status, 404)
        }
    }
}

private struct EmptyResponse: Decodable {}
