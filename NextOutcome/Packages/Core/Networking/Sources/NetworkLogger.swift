//
//  NetworkLogger.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import os

/// Pretty-prints outgoing requests and incoming responses to the unified log (and Xcode console).
/// Enabled in DEBUG by default, silent in release. Inject `.disabled` in tests.
public struct NetworkLogger: Sendable {
    /// How much detail to print for each request/response.
    /// Cases are ordered from least to most verbose so they can be compared
    /// (`.basic < .verbose`) to decide whether a given log line should be printed.
    public enum Level: Int, Sendable, Comparable {
        /// Log nothing at all.
        case none
        /// Log a one-line summary per request/response (method, URL, status code).
        case basic
        /// Log everything `.basic` logs, plus headers (redacted) and pretty-printed
        /// JSON bodies. Useful for local debugging, too noisy for production.
        case verbose

        /// Allows `Level` values to be compared (e.g. `level >= .basic`) so logging
        /// code can gate output based on verbosity.
        public static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// How verbose this logger instance is. Set once at initialization.
    private let level: Level

    /// The underlying system logger this writes to, visible in Console.app and the
    /// Xcode console.
    private let logger = Logger(subsystem: "com.nextoutcome.networking", category: "Network")

    /// Creates a logger with a specific verbosity level.
    /// - Parameter level: How much detail to print.
    public init(level: Level) {
        self.level = level
    }

    /// Verbose in DEBUG (body included), off in release.
    public static var `default`: NetworkLogger {
        #if DEBUG
        NetworkLogger(level: .verbose)
        #else
        NetworkLogger(level: .none)
        #endif
    }

    /// A logger that never prints anything. Use this in unit tests so test runs
    /// don't fill the console with network noise.
    public static let disabled = NetworkLogger(level: .none)

    // MARK: - Request

    /// Logs an outgoing request before it's sent.
    ///
    /// At `.basic` level, prints the method and URL. At `.verbose` level, also
    /// prints redacted headers and a pretty-printed JSON body (if present).
    /// Does nothing if `level` is `.none`.
    /// - Parameter request: The request about to be sent.
    func log(request: URLRequest) {
        guard level >= .basic else { return }
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "<nil url>"
        var lines = ["⬆️ \(method) \(url)"]
        if level >= .verbose {
            if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
                lines.append("   headers: \(redact(headers))")
            }
            if let body = request.httpBody, let text = prettyJSON(body) {
                lines.append("   body: \(text)")
            }
        }
        logger.debug("\(lines.joined(separator: "\n"), privacy: .public)")
    }

    // MARK: - Response

    /// Logs a completed response.
    ///
    /// At `.basic` level, prints a ✅/⚠️ icon (based on status code), the status
    /// code, URL, and byte count. At `.verbose` level, also pretty-prints the
    /// response body as JSON if possible. Does nothing if `level` is `.none`.
    /// - Parameters:
    ///   - response: The raw `URLResponse` (used to read the HTTP status code).
    ///   - data: The raw response body bytes.
    ///   - request: The original request, used to log its URL alongside the response.
    func log(response: URLResponse?, data: Data, request: URLRequest) {
        guard level >= .basic else { return }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let url = request.url?.absoluteString ?? "<nil url>"
        let icon = (200..<300).contains(status) ? "✅" : "⚠️"
        var lines = ["\(icon) \(status) \(url) (\(data.count) bytes)"]
        if level >= .verbose, let text = prettyJSON(data) {
            lines.append("   \(text)")
        }
        logger.debug("\(lines.joined(separator: "\n"), privacy: .public)")
    }

    // MARK: - Error

    /// Logs a request that failed outright (e.g. no connection, timeout) rather
    /// than one that got an HTTP error status. Always logged at the `.error` log
    /// level (so it shows up even if console filtering hides `.debug`), but only
    /// if `level` is at least `.basic`.
    /// - Parameters:
    ///   - error: The underlying error that occurred.
    ///   - request: The request that failed, used to log its URL.
    func log(error: Error, request: URLRequest) {
        guard level >= .basic else { return }
        let url = request.url?.absoluteString ?? "<nil url>"
        logger.error("❌ \(url, privacy: .public) — \(String(describing: error), privacy: .public)")
    }

    // MARK: - Helpers

    /// Attempts to format raw response/request body bytes as indented, readable JSON
    /// for logging. Falls back to a plain UTF-8 string if the bytes aren't valid JSON.
    /// Truncates very long output so a single huge payload doesn't flood the console.
    /// - Parameters:
    ///   - data: The raw body bytes to format.
    ///   - limit: The maximum number of characters to include before truncating.
    ///     Defaults to 4000.
    /// - Returns: A pretty-printed (or plain-text) string, or `nil` if `data` is empty.
    private func prettyJSON(_ data: Data, limit: Int = 4000) -> String? {
        guard !data.isEmpty else { return nil }
        let pretty: String
        if let object = try? JSONSerialization.jsonObject(with: data),
           let formatted = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .withoutEscapingSlashes]),
           let text = String(data: formatted, encoding: .utf8) {
            pretty = text
        } else {
            pretty = String(decoding: data, as: UTF8.self)
        }
        return pretty.count > limit ? String(pretty.prefix(limit)) + "\n   …(truncated)" : pretty
    }

    /// Never log auth material verbatim.
    ///
    /// Replaces the values of known sensitive headers (authorization tokens, API
    /// keys, cookies, Polymarket signature headers) with `"***"` before they're
    /// printed, so credentials never end up in console output or crash logs.
    /// - Parameter headers: The original request headers.
    /// - Returns: A copy of `headers` with sensitive values masked.
    private func redact(_ headers: [String: String]) -> [String: String] {
        let sensitive = ["authorization", "poly_signature", "poly_api_key", "poly-api-key", "cookie", "x-api-key"]
        return headers.reduce(into: [:]) { result, pair in
            result[pair.key] = sensitive.contains(pair.key.lowercased()) ? "***" : pair.value
        }
    }
}
