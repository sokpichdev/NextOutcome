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
    private let url: URL
    private let decoder: JSONDecoder
    private let logger = Logger(subsystem: "com.nextoutcome.networking", category: "MarketSocket")

    public init(
        url: URL = URL(string: "wss://ws-subscriptions-clob.polymarket.com/ws/market")!,
        decoder: JSONDecoder = .polymarket
    ) {
        self.url = url
        self.decoder = decoder
    }

    public func events(assetID: String) -> AsyncStream<OrderBookEvent> {
        AsyncStream { continuation in
            let task = Task { await run(assetID: assetID, continuation: continuation) }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

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

    private func subscribe(_ socket: URLSessionWebSocketTask, assetID: String) async throws {
        let payload: [String: Any] = [
            "assets_ids": [assetID],
            "type": "market",
            "custom_feature_enabled": true,
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        try await socket.send(.data(data))
    }

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

    /// Messages may arrive as a single object or an array of objects.
    private func decode(_ data: Data) -> [OrderBookEvent] {
        if let messages = try? decoder.decode([MarketMessageDTO].self, from: data) {
            return messages.flatMap(OrderbookMapper.events(from:))
        }
        if let message = try? decoder.decode(MarketMessageDTO.self, from: data) {
            return OrderbookMapper.events(from: message)
        }
        return []
    }

    /// 0.5s, 1s, 2s … capped at 30s, with ±20% jitter.
    private func backoffNanos(_ attempt: Int) -> UInt64 {
        let base = min(30.0, 0.5 * pow(2.0, Double(attempt - 1)))
        let jittered = base * Double.random(in: 0.8...1.2)
        return UInt64(jittered * 1_000_000_000)
    }
}
