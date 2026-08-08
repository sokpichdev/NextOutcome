//
//  Endpoint.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation

/// A plain description of a single API call: which Polymarket service to hit, which
/// path on that service, which HTTP method, and any query parameters or request body.
///
/// `Endpoint` itself doesn't perform the network call — it's a value type that
/// `APIClient`/`HTTPTransport` turns into a real `URLRequest` and executes. Building
/// requests this way keeps the "what to call" logic (usually defined per-repository)
/// separate from the "how to actually make an HTTP call" logic (shared plumbing).
public struct Endpoint {
    /// Which Polymarket backend service this request targets (Gamma, CLOB, etc.).
    /// Determines the base URL used to build the final request.
    public let host: PolymarketService

    /// The URL path to call on that host, e.g. `"/events"`.
    public let path: String

    /// The HTTP verb to use. Defaults to `.get` since most calls are reads.
    public let method: HTTPMethod

    /// Query string parameters to append to the URL, as key/value pairs.
    /// Empty by default.
    public let query: [String: String]

    /// The raw request body to send, if any (already-encoded JSON `Data`).
    /// `nil` for requests with no body, such as most GET requests.
    public let body: Data?

    /// Creates a description of an API call.
    /// - Parameters:
    ///   - host: The backend service to call.
    ///   - path: The URL path on that host.
    ///   - method: The HTTP method to use. Defaults to `.get`.
    ///   - query: Query string parameters. Defaults to none.
    ///   - body: An already-encoded request body. Defaults to `nil`.
    public init(
        host: PolymarketService,
        path: String,
        method: HTTPMethod = .get,
        query: [String: String] = [:],
        body: Data? = nil
    ) {
        self.host = host
        self.path = path
        self.method = method
        self.query = query
        self.body = body
    }

    /// Builds a real `URLRequest` from this endpoint's host, path, method, query,
    /// and body.
    ///
    /// Returns `nil` if the pieces don't add up to a valid URL (for example, an
    /// invalid path). Callers should check for `nil` and surface an error
    /// (e.g. `APIError.badURL`) instead of force-unwrapping.
    ///
    /// - Important: If `body` is non-nil, this automatically sets the
    ///   `Content-Type: application/json` header, since every endpoint in this app
    ///   that sends a body sends JSON.
    public var urlRequest: URLRequest? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host.baseURL
        components.path = path
        if !query.isEmpty {
            components.queryItems = query.map {
                URLQueryItem(name: $0.key, value: $0.value)
            }
        }
        guard let url = components.url else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }
}
