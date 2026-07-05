//
//  MoverTopicKey.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import Foundation

/// Pure, testable extractor for a mover's "topic" — the subject plus any month/day mentioned
/// in its question — used to collapse near-duplicate markets that Polymarket lists as
/// *separate events* (e.g. "GPT-5.6 released by July 7, 2026?" and "Will GPT-5.6 be released
/// on July 7, 2026?" are two distinct event ids for the same real-world question, so the
/// per-event collapse in `MoverRanking` can't merge them on its own).
public enum MoverTopicKey {
    /// Filler words stripped before comparing subjects, so phrasing differences ("released
    /// by" vs "be released on") don't stop two questions about the same thing from matching.
    private static let stopwords: Set<String> = [
        "will", "be", "is", "are", "being", "on", "by", "the", "a", "an",
        "released", "happen", "get", "of", "to", "in", "this", "that",
    ]

    /// Full month names, used to find a date mention in the question.
    private static let months = [
        "january", "february", "march", "april", "may", "june",
        "july", "august", "september", "october", "november", "december",
    ]

    /// Extracts a normalized "subject|month day" key from a question, or `nil` if no date is
    /// mentioned. Movers with no detectable date aren't merged by topic — only an explicit
    /// shared subject *and* date is a strong enough signal to collapse across event ids.
    /// - Parameter question: The market question text.
    /// - Returns: A stable key shared by same-subject, same-date questions, or `nil`.
    public static func key(for question: String) -> String? {
        let lower = question.lowercased()
        guard let dateRange = dateRange(in: lower) else { return nil }
        let dateText = lower[dateRange].trimmingCharacters(in: .whitespaces)

        var withoutDate = lower
        withoutDate.removeSubrange(dateRange)

        let subject = withoutDate
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "-" && $0 != "." })
            .map(String.init)
            .filter { !stopwords.contains($0) && !$0.isEmpty }
            .sorted()
            .joined(separator: " ")

        guard !subject.isEmpty else { return nil }
        return "\(subject)|\(dateText)"
    }

    /// Finds the range of the first "\<month\> \<day\>" mention in an already-lowercased string.
    private static func dateRange(in lower: String) -> Range<String.Index>? {
        for month in months {
            guard let monthRange = lower.range(of: month) else { continue }
            var dayStart = monthRange.upperBound
            while dayStart < lower.endIndex, lower[dayStart] == " " {
                dayStart = lower.index(after: dayStart)
            }
            var dayEnd = dayStart
            while dayEnd < lower.endIndex, lower[dayEnd].isNumber {
                dayEnd = lower.index(after: dayEnd)
            }
            guard dayEnd > dayStart else { continue }
            return monthRange.lowerBound..<dayEnd
        }
        return nil
    }
}
