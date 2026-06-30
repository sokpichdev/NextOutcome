import Foundation
@testable import Networking

final class MockTransport: HTTPTransport {
    var stubbedData: Data = Data()
    var stubbedStatus: Int = 200
    var capturedRequests: [URLRequest] = []

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        capturedRequests.append(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stubbedStatus,
            httpVersion: nil,
            headerFields: nil
        )!
        return (stubbedData, response)
    }
}
