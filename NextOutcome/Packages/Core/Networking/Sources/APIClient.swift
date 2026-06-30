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
    
    public init(
        transport: HTTPTransport = URLSession.shared,
        decoder: JSONDecoder = .polymarket,
        retry: RetryPolicy = .default
    ) {
        self.transport = transport
        self.decoder = decoder
        self.retry = retry
    }
    
    public func fetch<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        guard let reques = endpoint.urlRequest else {
            throw APIError.badURL
        }
        for attempt in 0..<retry.maxAttempts {
            do {
                let (data, response) = try await transport.data(for: reques)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                if status == 429 { throw APIError.rateLimited }
                guard (200..<300).contains(status) else {
                    throw APIError.http(statusCode: status, body: data)
                }
                return try decoder.decode(T.self, from: data)
            } catch let error as APIError {
                let isLast = attempt == retry.maxAttempts - 1
                if isLast { throw error }
                try await Task.sleep(nanoseconds: UInt64(retry.delay(for: attempt) * 1_000_000_000))
            } catch {
                throw APIError.unknown(error)
            }
        }
        throw APIError.unknown(URLError(.unknown))
    }
}
