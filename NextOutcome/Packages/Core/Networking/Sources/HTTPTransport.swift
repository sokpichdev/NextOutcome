//
//  HTTPTransport.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation

/// An abstraction over "something that can perform a network request and return
/// raw bytes back". `APIClient` depends on this protocol instead of talking to
/// `URLSession` directly.
///
/// The main reason this exists is testability: in unit tests you can create a
/// mock conforming to `HTTPTransport` that returns canned data instead of hitting
/// the real network (see `MockTransport` in the test target).
public protocol HTTPTransport: Sendable {
    /// Performs a network request and returns the raw response data along with
    /// metadata about the response (status code, headers, etc.).
    /// - Parameter request: The request to perform.
    /// - Returns: A tuple of the raw response body bytes and the URL response.
    /// - Throws: Any error the underlying transport encounters (e.g. no connection).
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// Makes `URLSession` usable as an `HTTPTransport`, so the app's real networking
/// path is just `URLSession.shared` with no extra wrapper needed.
extension URLSession: HTTPTransport {
    /// Forwards to `URLSession`'s built-in `data(for:delegate:)`, passing `nil` for
    /// the delegate since this app doesn't need custom session delegate behavior.
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request, delegate: nil)
    }
}
