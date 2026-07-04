//
//  HTTPMethod.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

/// The HTTP verb used when building a request via `Endpoint`.
///
/// Raw values match the actual HTTP method strings so they can be assigned
/// directly to `URLRequest.httpMethod`.
public enum HTTPMethod: String {
    /// Used for read-only requests (fetching markets, events, portfolio data, etc.).
    case get = "GET"

    /// Used for requests that create or submit something (e.g. placing an order).
    case post = "POST"

    /// Used for requests that remove something server-side (e.g. cancelling an order).
    case delete = "DELETE"
}
