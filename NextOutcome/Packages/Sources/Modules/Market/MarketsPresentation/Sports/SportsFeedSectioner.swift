//
//  SportsFeedSectioner.swift
//  NextOutcome
//
//  Created by Sok Pich on 16/08/2026.
//

import Foundation
import MarketsDomain

/// One dated band of the Sports Live feed — "Live now", "Today", "Tomorrow", "Wed 19 Aug".
public struct SportsFeedSection: Identifiable {
    /// Stable identity: `"live"` for the in-play band, else the day's start as an ISO day.
    public let id: String
    /// The header shown above the band.
    public let title: String
    /// The games in the band, kickoff order.
    public let events: [Event]

    /// Creates a section.
    public init(id: String, title: String, events: [Event]) {
        self.id = id
        self.title = title
        self.events = events
    }
}

/// Turns a flat page of sports events into the Live feed's dated sections.
///
/// The feed used to be one undifferentiated pile grouped by league, which put a "2027
/// Champion" future between two in-play matches. Three rules fix that: only games belong
/// here, esports belongs to its own hub, and what a reader wants first is what is on now.
enum SportsFeedSectioner {
    /// The Gamma tag marking an event as esports.
    static let esportsTagID = "64"
    /// Identifies the in-play band, which has no calendar day of its own.
    static let liveSectionID = "live"

    /// Sections a page of events: in-play games first, then one section per calendar day.
    ///
    /// Futures are dropped rather than shown in a trailing section — the hub's mode bar
    /// already has a Futures tab, so keeping them here would duplicate it. Esports is dropped
    /// for the same reason the chip row filters it: it has a dedicated hub, and showing its
    /// matches under chips that exclude it reads as a bug.
    ///
    /// - Parameters:
    ///   - events: The events loaded so far, in any order.
    ///   - results: Loaded scores, consulted for in-play state the event's own flag may lack.
    ///   - now: The current time, injected so "Today" is testable.
    ///   - calendar: The calendar bucketing days, injected for the same reason.
    static func sections(
        for events: [Event],
        results: [String: GameResult],
        now: Date,
        calendar: Calendar = .current
    ) -> [SportsFeedSection] {
        let games = WorldCupEventSplitter.split(events).games
            .filter { !$0.tags.contains { $0.id == esportsTagID } }

        // An ended game is not "on now" even though its result is loaded, so it stays with
        // the day it was played.
        let (live, scheduled) = games.reduce(into: ([Event](), [Event]())) { partial, event in
            let result = results[event.id]
            let isEnded = result?.ended ?? event.isEnded
            let isLive = result?.live ?? event.isLive
            if isLive, !isEnded { partial.0.append(event) } else { partial.1.append(event) }
        }

        var sections: [SportsFeedSection] = []
        if !live.isEmpty {
            let ordered = live.sorted {
                ($0.gameStartTime ?? .distantPast, $0.id) < ($1.gameStartTime ?? .distantPast, $1.id)
            }
            sections.append(SportsFeedSection(id: liveSectionID, title: "Live now", events: ordered))
        }
        sections += WorldCupEventSplitter.gamesByDay(scheduled, calendar: calendar).map { day, games in
            SportsFeedSection(id: Self.dayID(day, calendar: calendar),
                              title: Self.title(for: day, now: now, calendar: calendar),
                              events: games)
        }
        return sections
    }

    /// A stable per-day identity that doesn't shift with locale or time zone.
    private static func dayID(_ day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    /// "Today" and "Tomorrow" where they apply, else a short date like "Wed 19 Aug".
    private static func title(for day: Date, now: Date, calendar: Calendar) -> String {
        let today = calendar.startOfDay(for: now)
        if calendar.isDate(day, inSameDayAs: today) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
           calendar.isDate(day, inSameDayAs: tomorrow) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: day)
    }
}
