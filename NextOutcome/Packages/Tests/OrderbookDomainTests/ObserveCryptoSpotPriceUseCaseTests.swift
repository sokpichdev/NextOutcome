import XCTest
@testable import OrderbookDomain
import Foundation

/// No-op / preset fakes for the two ports `ObserveCryptoSpotPriceUseCase` folds together.
private struct FakeCryptoSpotPriceStreaming: CryptoSpotPriceStreaming {
    /// Live points to emit, in order, before finishing.
    let points: [CryptoSpotPricePoint]
    /// Captures the symbol the stream was opened with, so a test can assert mapping.
    let recordSymbol: (@Sendable (String) -> Void)?

    init(points: [CryptoSpotPricePoint], recordSymbol: (@Sendable (String) -> Void)? = nil) {
        self.points = points
        self.recordSymbol = recordSymbol
    }

    func prices(symbol: String) -> AsyncStream<CryptoSpotPricePoint> {
        recordSymbol?(symbol)
        return AsyncStream { continuation in
            for point in points { continuation.yield(point) }
            continuation.finish()
        }
    }
}

/// Minimal `CryptoSpotPriceRepository` returning a preset seed history.
private struct FakeCryptoSpotPriceRepository: CryptoSpotPriceRepository {
    let history: [CryptoSpotPricePoint]

    func spotPriceHistory(symbol: String, eventStart: Date, eventEnd: Date) async throws -> [CryptoSpotPricePoint] {
        history
    }

    func priceWindow(symbol: String, eventStart: Date, eventEnd: Date) async throws -> CryptoPriceWindow {
        CryptoPriceWindow(openPrice: nil, closePrice: nil, timestamp: Date(), completed: false)
    }
}

final class ObserveCryptoSpotPriceUseCaseTests: XCTestCase {
    private func date(_ offset: TimeInterval) -> Date { Date(timeIntervalSince1970: offset) }

    /// The use case must first yield the REST-seeded history (so the chart isn't blank on
    /// entry), then yield a new growing series each time a live socket point arrives —
    /// mirroring `ObserveOrderBookUseCase`'s seed-then-fold contract, but for the dollar
    /// spot-price series instead of the order book.
    func test_seedsWithRestHistory_thenAppendsEachLivePoint() async {
        let history = [
            CryptoSpotPricePoint(date: date(0), price: 63_000),
            CryptoSpotPricePoint(date: date(60), price: 63_010),
        ]
        let live = [
            CryptoSpotPricePoint(date: date(120), price: 63_025),
            CryptoSpotPricePoint(date: date(180), price: 63_040),
        ]
        let useCase = ObserveCryptoSpotPriceUseCase(
            repository: FakeCryptoSpotPriceRepository(history: history),
            stream: FakeCryptoSpotPriceStreaming(points: live)
        )

        var emissions: [[CryptoSpotPricePoint]] = []
        for await series in useCase.execute(symbol: "BTC", eventStart: date(0), eventEnd: date(300)) {
            emissions.append(series)
        }

        XCTAssertEqual(emissions.count, 3, "one seed emission + one per live point")
        XCTAssertEqual(emissions[0], history)
        XCTAssertEqual(emissions[1], history + [live[0]])
        XCTAssertEqual(emissions[2], history + live)
        XCTAssertEqual(emissions.last?.last?.price, 63_040, "currentPrice source must be the newest live point")
    }

    /// The live stream must be opened with the event's own asset symbol (BTC, ETH, SOL, …),
    /// never a hardcoded one — the same regression guard the polling path already has.
    func test_opensStreamWithProvidedSymbol() async {
        final class Box: @unchecked Sendable { var symbols: [String] = [] }
        let box = Box()
        let useCase = ObserveCryptoSpotPriceUseCase(
            repository: FakeCryptoSpotPriceRepository(history: []),
            stream: FakeCryptoSpotPriceStreaming(points: []) { box.symbols.append($0) }
        )

        for await _ in useCase.execute(symbol: "ETH", eventStart: date(0), eventEnd: date(300)) {}

        XCTAssertEqual(box.symbols, ["ETH"])
    }
}
