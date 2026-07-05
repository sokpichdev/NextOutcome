//
//  CandidateDateExtractor.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import Foundation

/// Pure, testable date extractor for ordering a mover's listing rows chronologically.
///
/// Some grouped events (e.g. "GPT-5.6 released on…?") give every sibling market the *same*
/// settlement `endDate` — the specific day each market bets on lives only in its label text
/// ("July 6", "June 24 or earlier", "Not released before August"). This extracts a "month day"
/// mentioned in that label so the listing can still be ordered chronologically like the web,
/// instead of falling back to whatever order Gamma's API happened to return.
enum CandidateDateExtractor {
    /// Full month names, used to find a date mention in a label.
    private static let months = [
        "january", "february", "march", "april", "may", "june",
        "july", "august", "september", "october", "november", "december",
    ]

    /// Extracts a "month day" date from a label, using the given reference date's year.
    /// - Parameters:
    ///   - text: The label to search (e.g. a market's `groupItemTitle` or `question`).
    ///   - referenceDate: Supplies the year to combine with the parsed month/day.
    ///   - calendar: The calendar to build the date with.
    /// - Returns: The parsed date, or `nil` if no "\<month\> \<day\>" mention is found.
    static func extractedDate(from text: String, referenceDate: Date = Date(), calendar: Calendar = .current) -> Date? {
        let lower = text.lowercased()
        for (index, month) in months.enumerated() {
            guard let monthRange = lower.range(of: month) else { continue }
            var dayStart = monthRange.upperBound
            while dayStart < lower.endIndex, lower[dayStart] == " " {
                dayStart = lower.index(after: dayStart)
            }
            var dayEnd = dayStart
            while dayEnd < lower.endIndex, lower[dayEnd].isNumber {
                dayEnd = lower.index(after: dayEnd)
            }
            guard dayEnd > dayStart, let day = Int(lower[dayStart..<dayEnd]) else { continue }
            var components = calendar.dateComponents([.year], from: referenceDate)
            components.month = index + 1
            components.day = day
            return calendar.date(from: components)
        }
        return nil
    }
}
