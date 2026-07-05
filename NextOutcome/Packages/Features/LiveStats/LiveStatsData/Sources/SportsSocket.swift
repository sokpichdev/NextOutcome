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
    /// The WebSocket URL to connect to.
    private let url: URL
    /// Decoder used to turn incoming frames into `SportsFrameDTO`.
    private let decoder: JSONDecoder
    /// Logs connection drops (never logs sensitive data).
    private let logger = Logger(subsystem: "com.nextoutcome.networking", category: "SportsSocket")

    /// Creates the socket.
    /// - Parameters:
    ///   - url: The feed URL. Defaults to Polymarket's sports WebSocket.
    ///   - decoder: The JSON decoder to use. Defaults to a plain `JSONDecoder`.
    public init(
        url: URL = URL(string: "wss://sports-api.polymarket.com/ws")!,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.url = url
        self.decoder = decoder
    }

    /// Starts streaming snapshots for one game (see `SportsStateStreaming`).
    ///
    /// Wraps the reconnect loop in an `AsyncThrowingStream` and cancels the underlying
    /// task automatically when the consumer stops iterating.
    public func states(gameID: String) -> AsyncThrowingStream<MatchState, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { await run(gameID: gameID, continuation: continuation) }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// The outer connect/reconnect loop: connects, pings, drains messages, and on any
    /// drop waits with exponential back-off before trying again — until the task is
    /// cancelled, at which point it finishes the stream.
    /// - Parameters:
    ///   - gameID: The game to filter frames to.
    ///   - continuation: The stream continuation to yield snapshots into.
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

    /// The inner receive loop: reads messages off one live connection, decodes each,
    /// keeps only frames for the requested game, merges them onto the previous snapshot,
    /// and yields the result. Throws when the connection drops so `run` can reconnect.
    /// - Parameters:
    ///   - socket: The active WebSocket task to read from.
    ///   - gameID: The game to filter to.
    ///   - latest: The most recent snapshot, carried forward so unresent fields persist.
    ///   - continuation: The stream continuation to yield onto.
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

    /// Computes the reconnect delay for a given attempt: 0.5s, 1s, 2s … capped at 30s,
    /// with ±20% random jitter so many clients don't all reconnect in lockstep.
    /// - Parameter attempt: The 1-based reconnect attempt number.
    /// - Returns: The delay in nanoseconds, ready for `Task.sleep`.
    private func backoffNanos(_ attempt: Int) -> UInt64 {
        let base = min(30.0, 0.5 * pow(2.0, Double(attempt - 1)))
        let jittered = base * Double.random(in: 0.8...1.2)
        return UInt64(jittered * 1_000_000_000)
    }
}
