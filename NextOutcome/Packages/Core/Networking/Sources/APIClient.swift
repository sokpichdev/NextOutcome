//
//  APIClient.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation

public actor APIClient {
    private let transport: HTTPTransport
    private let decoder: JSONDecoder
    private let retry: RetryPolicy
    private let logger: NetworkLogger

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
                // Decoding is deterministic; only retry transport/throttle/status errors.
                if case .decoding = error { throw error }
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
