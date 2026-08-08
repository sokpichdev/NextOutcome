//
//  APIError.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation

/// The set of errors that can occur while making a network request through
/// `APIClient`/`HTTPTransport`. Repositories and view models catch this type to
/// decide how to react (e.g. show a retry button vs. a generic error message).
public enum APIError: Error {
    /// The endpoint's host/path/query couldn't be turned into a valid URL.
    /// Usually indicates a bug in how the endpoint was constructed rather than
    /// something the user can fix.
    case badURL

    /// The server responded with a non-2xx HTTP status code.
    /// - Parameters:
    ///   - statusCode: The HTTP status code returned (e.g. 404, 500).
    ///   - body: The raw response body, kept around for logging/debugging.
    case http(statusCode: Int, body: Data)

    /// The response body couldn't be decoded into the expected model type.
    /// - Parameter Error: The underlying decoding error (e.g. from `JSONDecoder`).
    case decoding(Error)

    /// The server rejected the request because too many requests were made too
    /// quickly. Callers may want to back off and retry after a delay.
    case rateLimited

    /// Any other error that doesn't fit the cases above (e.g. no internet connection).
    /// - Parameter Error: The underlying system/URLSession error.
    case unknown(Error)
}
