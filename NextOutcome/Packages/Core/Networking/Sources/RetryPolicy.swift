//
//  RetryPolicy.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation

/// Describes how a network call should retry after a failure: how many attempts to
/// make in total, and how long to wait between them.
///
/// The wait time grows exponentially with each retry (see `delay(for:)`), which is a
/// standard "backoff" strategy so a struggling server or spotty connection isn't
/// hammered with immediate repeat requests.
public struct RetryPolicy {
    /// The maximum number of attempts to make, including the first (non-retry) attempt.
    /// For example, `3` means: try once, and if it fails, retry up to 2 more times.
    public let maxAttempts: Int

    /// The starting delay, in seconds, used as the base for the exponential backoff
    /// calculation in `delay(for:)`.
    public let baseDelay: TimeInterval

    /// A sensible default: up to 3 attempts total, starting with a 0.5 second delay
    /// that doubles on each subsequent attempt. Use this for most API calls.
    public static let `default` = RetryPolicy(maxAttempts: 3, baseDelay: 0.5)

    /// No retries at all — one attempt only, with no delay. Use this for calls where
    /// retrying wouldn't make sense (e.g. one-shot actions) or in tests where you want
    /// deterministic, immediate failure.
    public static let none = RetryPolicy(maxAttempts: 1, baseDelay: 0)

    /// Calculates how long to wait before a given retry attempt, using exponential
    /// backoff (`baseDelay * 2^attempt`).
    ///
    /// - Parameter attemp: The zero-based index of the retry attempt (e.g. `0` for the
    ///   first retry after the initial failed attempt, `1` for the second, etc.).
    /// - Returns: The delay in seconds to wait before making that attempt.
    public func delay(for attemp: Int) -> TimeInterval {
        baseDelay * pow(2.0, Double(attemp))
    }
}
