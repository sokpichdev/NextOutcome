//
//  SportsSocket.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import Foundation
import LiveStatsDomain
import os

/// Reconnecting client for the sports live-data WebSocket
/// (`wss://sports-api.polymarket.com/ws`). The feed broadcasts full-state snapshots for
/// many games; each `states(gameID:)` call filters to the requested game, maps frames to
/// `MatchState`, and transparently reconnects with exponential back-off until the consumer
/// stops iterating. Mirrors `MarketSocket`'s reconnect/back-off/cancellation shape.
public struct SportsSocket: SportsStateStreaming {
    private let url: URL
    private let decoder: JSONDecoder
    private let logger = Logger(subsystem: "com.nextoutcome.networking", category: "SportsSocket")

    public init(
        url: URL = URL(string: "wss://sports-api.polymarket.com/ws")!,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.url = url
        self.decoder = decoder
    }

    public func states(gameID: String) -> AsyncThrowingStream<MatchState, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { await run(gameID: gameID, continuation: continuation) }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(
        gameID: String,
        continuation: AsyncThrowingStream<MatchState, Error>.Continuation
    ) async {
        let session = URLSession(configuration: .default)
        var attempt = 0
        var latest: MatchState?

        while !Task.isCancelled {
            let socket = session.webSocketTask(with: url)
            socket.resume()
            do {
                try await socket.send(.string("PING"))
                attempt = 0  // connected — reset back-off
                try await receiveLoop(socket, gameID: gameID, latest: &latest, continuation: continuation)
            } catch {
                if Task.isCancelled { break }
                logger.error("sports socket \(gameID, privacy: .public) dropped: \(String(describing: error), privacy: .public)")
            }
            socket.cancel(with: .goingAway, reason: nil)

            if Task.isCancelled { break }
            attempt += 1
            try? await Task.sleep(nanoseconds: backoffNanos(attempt))
        }
        continuation.finish()
    }

    private func receiveLoop(
        _ socket: URLSessionWebSocketTask,
        gameID: String,
        latest: inout MatchState?,
        continuation: AsyncThrowingStream<MatchState, Error>.Continuation
    ) async throws {
        while !Task.isCancelled {
            let message = try await socket.receive()
            let data: Data
            switch message {
            case let .data(payload): data = payload
            case let .string(text): data = Data(text.utf8)
            @unknown default: continue
            }
            guard let frame = try? decoder.decode(SportsFrameDTO.self, from: data),
                  frame.metadataGameId == gameID,
                  let state = frame.toMatchState(previous: latest)
            else { continue }
            latest = state
            continuation.yield(state)
        }
    }

    /// 0.5s, 1s, 2s … capped at 30s, with ±20% jitter. Matches `MarketSocket`.
    private func backoffNanos(_ attempt: Int) -> UInt64 {
        let base = min(30.0, 0.5 * pow(2.0, Double(attempt - 1)))
        let jittered = base * Double.random(in: 0.8...1.2)
        return UInt64(jittered * 1_000_000_000)
    }
}
