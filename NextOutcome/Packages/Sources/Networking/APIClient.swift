//
//  APIClient.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation

/// The single entry point every repository in the app uses to talk to Polymarket's
/// APIs. Turns an `Endpoint` into a real network call, decodes the JSON response
/// into a model type, and handles retries, rate-limit detection, and logging along
/// the way.
///
/// This is an `actor` (rather than a class) so that its internal state is safe to
/// use from multiple concurrent `Task`s without needing manual locking — Swift's
/// concurrency checker enforces that only one task touches this actor's state at a
/// time.
public actor APIClient {
    /// The underlying thing that actually performs HTTP requests. Usually
    /// `URLSession.shared`, but can be swapped for a mock in tests.
    private let transport: HTTPTransport

    /// Decodes response bodies into model types. Defaults to a decoder configured
    /// for Polymarket's date/number formats (see `JSONDecoder.polymarket`).
    private let decoder: JSONDecoder

    /// Controls how many times, and how long to wait, before giving up on a
    /// retryable failure (network hiccups, 5xx errors).
    private let retry: RetryPolicy

    /// Writes request/response details to the console for debugging.
    private let logger: NetworkLogger

    /// Creates an API client.
    /// - Parameters:
    ///   - transport: What performs the actual network call. Defaults to
    ///     `URLSession.shared`; override in tests with a mock transport.
    ///   - decoder: How to decode JSON responses. Defaults to `.polymarket`.
    ///   - retry: The retry/backoff policy for failed requests. Defaults to `.default`.
    ///   - logger: Where to send debug logging. Defaults to `.default`.
    public init(
        transport: HTTPTransport = URLSession.shared,
        decoder: JSONDecoder = .polymarket,
        retry: RetryPolicy = .default,
        logger: NetworkLogger = .default
    ) {
        self.transport = transport
        self.decoder = decoder
        self.retry = retry
        self.logger = logger
    }

    /// Performs a network request described by `endpoint` and decodes the response
    /// into `T`.
    ///
    /// This is the one method every repository calls to talk to the network. It
    /// handles the full lifecycle of a request:
    /// 1. Builds and logs the outgoing `URLRequest`.
    /// 2. Sends it via `transport`, logging the response.
    /// 3. Checks the HTTP status code — a `429` becomes `.rateLimited`, other
    ///    non-2xx codes become `.http(statusCode:body:)`.
    /// 4. Decodes the response body into `T`, wrapping decode failures in
    ///    `.decoding`.
    /// 5. On a retryable failure (anything that isn't a decoding error or a 4xx
    ///    client error), waits using `RetryPolicy.delay(for:)` and tries again, up
    ///    to `retry.maxAttempts` times.
    ///
    /// - Parameter endpoint: The request to perform.
    /// - Returns: The decoded response value.
    /// - Throws: `APIError.badURL` if the endpoint couldn't build a valid request;
    ///   `APIError.rateLimited` for HTTP 429; `APIError.http` for other non-2xx
    ///   status codes; `APIError.decoding` if the response body doesn't match `T`;
    ///   `APIError.unknown` for any other underlying error (e.g. no connection).
    /// - Important: Decoding failures and 4xx client errors are never retried,
    ///   since retrying them would just fail again in the same way. Only
    ///   transport-level errors, rate limiting, and 5xx server errors are retried.
    public func fetch<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        guard let reques = endpoint.urlRequest else {
            throw APIError.badURL
        }
        logger.log(request: reques)
        for attempt in 0..<retry.maxAttempts {
            do {
                let (data, response) = try await transport.data(for: reques)
                logger.log(response: response, data: data, request: reques)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                if status == 429 { throw APIError.rateLimited }
                guard (200..<300).contains(status) else {
                    throw APIError.http(statusCode: status, body: data)
                }
                do {
                    return try decoder.decode(T.self, from: data)
                } catch {
                    // Decoding failures are deterministic — don't retry them.
                    let decodingError = APIError.decoding(error)
                    logger.log(error: decodingError, request: reques)
                    throw decodingError
                }
            } catch let error as APIError {
                // Deterministic errors: never retry. Decoding and client (4xx) failures
                // won't change on a repeat — only transport/throttle/5xx are worth retrying.
                if case .decoding = error {
                    throw error
                }
                if case let .http(status, _) = error, (400..<500).contains(status) {
                    logger.log(error: error, request: reques)
                    throw error
                }
                let isLast = attempt == retry.maxAttempts - 1
                if isLast {
                    logger.log(error: error, request: reques)
                    throw error
                }
                try await Task.sleep(nanoseconds: UInt64(retry.delay(for: attempt) * 1_000_000_000))
            } catch {
                logger.log(error: error, request: reques)
                throw APIError.unknown(error)
            }
        }
        throw APIError.unknown(URLError(.unknown))
    }
}
