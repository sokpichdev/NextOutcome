//
//  MarketSocket.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import Networking
import OrderbookDomain
import os

/// Reconnecting client for the CLOB **market** WebSocket channel.
/// Each `events(assetID:)` call owns one subscription: it connects, subscribes,
/// streams normalized `OrderBookEvent`s, and transparently reconnects with
/// exponential back-off until the consumer stops iterating.
public struct MarketSocket: MarketStreaming {
    /// The market-channel WebSocket URL.
    private let url: URL
    /// Decoder for incoming frames (Polymarket's snake_case config).
    private let decoder: JSONDecoder
    /// Logs connection drops (never logs sensitive data).
    private let logger = Logger(subsystem: "com.nextoutcome.networking", category: "MarketSocket")

    /// Creates the socket.
    /// - Parameters:
    ///   - url: The feed URL. Defaults to Polymarket's CLOB market channel.
    ///   - decoder: The JSON decoder to use. Defaults to `.polymarket`.
    public init(
        url: URL = URL(string: "wss://ws-subscriptions-clob.polymarket.com/ws/market")!,
        decoder: JSONDecoder = .polymarket
    ) {
        self.url = url
        self.decoder = decoder
    }

    /// Starts streaming normalized book events for one token (see `MarketStreaming`).
    /// Cancels the underlying task automatically when the consumer stops iterating.
    public func events(assetID: String) -> AsyncStream<OrderBookEvent> {
        AsyncStream { continuation in
            let task = Task { await run(assetID: assetID, continuation: continuation) }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// The connect/reconnect loop: connects, subscribes, drains messages, and on any drop
    /// emits a `.reconnecting` state and waits with exponential back-off before retrying —
    /// until the task is cancelled.
    /// - Parameters:
    ///   - assetID: The token to subscribe to.
    ///   - continuation: The stream continuation to yield events into.
    private func run(assetID: String, continuation: AsyncStream<OrderBookEvent>.Continuation) async {
        let session = URLSession(configuration: .default)
        var attempt = 0

        while !Task.isCancelled {
            let socket = session.webSocketTask(with: url)
            socket.resume()
            do {
                try await subscribe(socket, assetID: assetID)
                attempt = 0  // connected — reset back-off
                continuation.yield(.connectionState(.live))
                try await receiveLoop(socket, continuation: continuation)
            } catch {
                if Task.isCancelled { break }
                logger.error("socket \(assetID, privacy: .public) dropped: \(String(describing: error), privacy: .public)")
                continuation.yield(.connectionState(.reconnecting))
            }
            socket.cancel(with: .goingAway, reason: nil)

            if Task.isCancelled { break }
            attempt += 1
            try? await Task.sleep(nanoseconds: backoffNanos(attempt))
        }
        continuation.finish()
    }

    /// Sends the initial subscription message telling the server which token we want.
    /// - Parameters:
    ///   - socket: The active WebSocket task.
    ///   - assetID: The token to subscribe to.
    private func subscribe(_ socket: URLSessionWebSocketTask, assetID: String) async throws {
        let payload: [String: Any] = [
            "assets_ids": [assetID],
            "type": "market",
            "custom_feature_enabled": true,
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        try await socket.send(.data(data))
    }

    /// Reads messages off one live connection, decodes each into events, and yields them.
    /// Throws when the connection drops so `run` can reconnect.
    /// - Parameters:
    ///   - socket: The active WebSocket task to read from.
    ///   - continuation: The stream continuation to yield onto.
    private func receiveLoop(
        _ socket: URLSessionWebSocketTask,
        continuation: AsyncStream<OrderBookEvent>.Continuation
    ) async throws {
        while !Task.isCancelled {
            let message = try await socket.receive()
            let data: Data
            switch message {
            case let .data(payload): data = payload
            case let .string(text): data = Data(text.utf8)
            @unknown default: continue
            }
            for event in decode(data) {
                continuation.yield(event)
            }
        }
    }

    /// Decodes one raw frame into events, tolerating both a single object and an array of
    /// objects (the feed uses both shapes). Malformed frames map to no events.
    /// - Parameter data: The raw frame bytes.
    /// - Returns: The normalized events (possibly empty).
    private func decode(_ data: Data) -> [OrderBookEvent] {
        if let messages = try? decoder.decode([MarketMessageDTO].self, from: data) {
            return messages.flatMap(OrderbookMapper.events(from:))
        }
        if let message = try? decoder.decode(MarketMessageDTO.self, from: data) {
            return OrderbookMapper.events(from: message)
        }
        return []
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
