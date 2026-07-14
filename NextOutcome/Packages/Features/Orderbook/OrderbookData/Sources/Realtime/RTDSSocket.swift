//
//  RTDSSocket.swift
//  NextOutcome
//

import Foundation
import OrderbookDomain
import os

/// Reconnecting client for Polymarket's **RTDS** feed
/// (`wss://ws-live-data.polymarket.com`) — the real-time data service that carries live
/// dollar crypto prices (and, separately, comments/activity). Each `prices(symbol:)` call
/// owns one subscription to the `crypto_prices_chainlink` topic, streams normalized
/// `CryptoSpotPricePoint`s, and transparently reconnects with exponential back-off until
/// the consumer stops iterating. Mirrors `MarketSocket`'s reconnect/back-off/cancellation
/// shape.
///
/// This replaces the BTC live screen's 5-second REST spot-price poll: web's "Current Price"
/// ticks from this feed, so the app now does too.
public struct RTDSSocket: CryptoSpotPriceStreaming {
    /// The RTDS WebSocket URL.
    private let url: URL
    /// Logs connection drops (never logs sensitive data).
    private let logger = Logger(subsystem: "com.nextoutcome.networking", category: "RTDSSocket")

    /// Creates the socket.
    /// - Parameter url: The feed URL. Defaults to Polymarket's RTDS host.
    public init(url: URL = URL(string: "wss://ws-live-data.polymarket.com")!) {
        self.url = url
    }

    /// Starts streaming live dollar spot-price samples for one asset (see
    /// `CryptoSpotPriceStreaming`). Cancels the underlying task automatically when the
    /// consumer stops iterating.
    public func prices(symbol: String) -> AsyncStream<CryptoSpotPricePoint> {
        let exchangeSymbol = RTDSCryptoPriceMapper.exchangeSymbol(for: symbol)
        return AsyncStream { continuation in
            let task = Task { await run(exchangeSymbol: exchangeSymbol, continuation: continuation) }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// The connect/reconnect loop: connects, subscribes to the crypto price topic, drains
    /// messages, and on any drop waits with exponential back-off before retrying — until the
    /// task is cancelled.
    /// - Parameters:
    ///   - exchangeSymbol: The exchange pair to subscribe to (e.g. `"BTCUSDT"`).
    ///   - continuation: The stream continuation to yield points into.
    private func run(
        exchangeSymbol: String,
        continuation: AsyncStream<CryptoSpotPricePoint>.Continuation
    ) async {
        let session = URLSession(configuration: .default)
        var attempt = 0

        while !Task.isCancelled {
            let socket = session.webSocketTask(with: url)
            socket.resume()
            do {
                try await socket.send(.string("ping"))  // RTDS pings on open, then subscribes
                try await subscribe(socket)
                attempt = 0  // connected — reset back-off
                let pinger = Task { await pingLoop(socket) }
                defer { pinger.cancel() }
                try await receiveLoop(socket, exchangeSymbol: exchangeSymbol, continuation: continuation)
            } catch {
                if Task.isCancelled { break }
                logger.error("rtds socket \(exchangeSymbol, privacy: .public) dropped: \(String(describing: error), privacy: .public)")
            }
            socket.cancel(with: .goingAway, reason: nil)

            if Task.isCancelled { break }
            attempt += 1
            try? await Task.sleep(nanoseconds: backoffNanos(attempt))
        }
        continuation.finish()
    }

    /// Sends the subscription frame (`action: "subscribe"`, `crypto_prices_chainlink` topic,
    /// server-filtered to the one symbol we're charting). The frame is built by
    /// `RTDSCryptoPriceMapper.subscribeMessage` so the exact wire format stays unit-tested.
    /// - Parameter socket: The active WebSocket task.
    private func subscribe(_ socket: URLSessionWebSocketTask) async throws {
        let data = RTDSCryptoPriceMapper.subscribeMessage()
        try await socket.send(.string(String(decoding: data, as: UTF8.self)))
    }

    /// Keeps the connection alive by sending a `"ping"` every 5 seconds, matching Polymarket's
    /// reference RTDS client — the server drops idle connections that don't ping. Stops when
    /// the connection ends (the task is cancelled by `run`'s `defer`).
    /// - Parameter socket: The active WebSocket task to ping.
    private func pingLoop(_ socket: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            try? await socket.send(.string("ping"))
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }

    /// Reads messages off one live connection, decodes each into a spot-price point (keeping
    /// only frames matching our symbol), and yields them. Throws when the connection drops so
    /// `run` can reconnect.
    /// - Parameters:
    ///   - socket: The active WebSocket task to read from.
    ///   - exchangeSymbol: The exchange pair to keep.
    ///   - continuation: The stream continuation to yield onto.
    private func receiveLoop(
        _ socket: URLSessionWebSocketTask,
        exchangeSymbol: String,
        continuation: AsyncStream<CryptoSpotPricePoint>.Continuation
    ) async throws {
        while !Task.isCancelled {
            let message = try await socket.receive()
            let data: Data
            switch message {
            case let .data(payload): data = payload
            case let .string(text): data = Data(text.utf8)
            @unknown default: continue
            }
            if let point = RTDSCryptoPriceMapper.point(from: data, exchangeSymbol: exchangeSymbol) {
                continuation.yield(point)
            }
        }
    }

    /// Computes the reconnect delay: 0.5s, 1s, 2s … capped at 30s, with ±20% jitter so
    /// clients don't reconnect in lockstep.
    /// - Parameter attempt: The 1-based reconnect attempt number.
    /// - Returns: The delay in nanoseconds for `Task.sleep`.
    private func backoffNanos(_ attempt: Int) -> UInt64 {
        let base = min(30.0, 0.5 * pow(2.0, Double(attempt - 1)))
        let jittered = base * Double.random(in: 0.8...1.2)
        return UInt64(jittered * 1_000_000_000)
    }
}
