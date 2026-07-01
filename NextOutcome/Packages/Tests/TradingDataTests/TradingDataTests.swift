import XCTest
import TradingDomain
@testable import TradingData

final class GeoblockDecodingTests: XCTestCase {
    func test_geoblockDTO_decodes() throws {
        let json = #"{"blocked": true, "closeOnly": false, "region": "US"}"#.data(using: .utf8)!
        let dto = try JSONDecoder().decode(GeoblockDTO.self, from: json)
        XCTAssertEqual(dto.blocked, true)
        XCTAssertEqual(dto.region, "US")
    }

    func test_geoblockDTO_toleratesMissing() throws {
        let dto = try JSONDecoder().decode(GeoblockDTO.self, from: Data("{}".utf8))
        XCTAssertNil(dto.blocked)
    }
}

final class UnavailableWalletSignerTests: XCTestCase {
    func test_signer_failsLoudly() async {
        let signer = UnavailableWalletSigner()
        do {
            _ = try await signer.signAttestation(address: "0xabc")
            XCTFail("expected signerUnavailable")
        } catch {
            XCTAssertEqual(error as? WalletError, .signerUnavailable)
        }
    }
}

final class KeychainCredentialStoreTests: XCTestCase {
    // Uses a unique service so it never collides with a real app keychain item.
    private let store = KeychainCredentialStore(service: "com.nextoutcome.trading.tests")

    override func tearDown() { try? store.clear(); super.tearDown() }

    func test_saveLoadClearRoundtrip() throws {
        try store.save(sessionToken: "sess-123")
        XCTAssertEqual(try store.loadSessionToken(), "sess-123")
        try store.clear()
        XCTAssertNil(try store.loadSessionToken())
    }
}
