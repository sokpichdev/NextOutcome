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
    public enum Level: Int, Sendable, Comparable {
        case none, basic, verbose
        public static func < (lhs: Level, rhs: Level) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    private let level: Level
    private let logger = Logger(subsystem: "com.nextoutcome.networking", category: "Network")

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

    public static let disabled = NetworkLogger(level: .none)

    // MARK: - Request

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

    func log(error: Error, request: URLRequest) {
        guard level >= .basic else { return }
        let url = request.url?.absoluteString ?? "<nil url>"
        logger.error("❌ \(url, privacy: .public) — \(String(describing: error), privacy: .public)")
    }

    // MARK: - Helpers

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
    private func redact(_ headers: [String: String]) -> [String: String] {
        let sensitive = ["authorization", "poly_signature", "poly_api_key", "poly-api-key", "cookie", "x-api-key"]
        return headers.reduce(into: [:]) { result, pair in
            result[pair.key] = sensitive.contains(pair.key.lowercased()) ? "***" : pair.value
        }
    }
}
