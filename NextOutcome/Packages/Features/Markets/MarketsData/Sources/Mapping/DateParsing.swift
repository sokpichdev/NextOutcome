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

    private static let spaceSeparatedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd HH:mm:ssZZZZZ"
        return f
    }()

    /// Parses standard ISO8601 timestamps, falling back to a fractional-seconds variant
    /// (e.g. Gamma comment `createdAt` values like `"2026-07-02T16:05:05.93448Z"`) and to
    /// the space-separated form Gamma uses for `gameStartTime` (`"2026-06-11 19:00:00+00"`).
    static func parse(_ string: String?) -> Date? {
        guard let string else { return nil }
        return ISO8601DateFormatter().date(from: string)
            ?? fractionalFormatter.date(from: string)
            ?? spaceSeparatedFormatter.date(from: string)
    }
}
