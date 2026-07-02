//
//  DateParsing.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation

enum DateParsing {
    private static let fractionalFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Parses standard ISO8601 timestamps, falling back to a fractional-seconds variant
    /// (e.g. Gamma comment `createdAt` values like `"2026-07-02T16:05:05.93448Z"`).
    static func parse(_ string: String?) -> Date? {
        guard let string else { return nil }
        return ISO8601DateFormatter().date(from: string) ?? fractionalFormatter.date(from: string)
    }
}
