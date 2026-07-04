//
//  WorldCupEventSplitter.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import Foundation

/// Splits a tournament series' events into schedulable games and everything else ("props":
/// winner futures, awards, player props, group futures) and groups games by matchday.
public enum WorldCupEventSplitter {
    /// The result of splitting a series' events into games versus props.
    public struct Split {
        /// Schedulable games (kickoff time + moneyline market).
        public let games: [Event]
        /// Everything else: winner futures, awards, player props, group futures.
        public let props: [Event]

        /// Creates a split result.
        public init(games: [Event], props: [Event]) {
            self.games = games
            self.props = props
        }
    }

    /// A game is an event with a kickoff time and a moneyline market; props events (player
    /// goals, futures) may carry a kickoff too, so the moneyline is the deciding signal.
    public static func split(_ events: [Event]) -> Split {
        var games: [Event] = []
        var props: [Event] = []
        for event in events {
            if event.gameStartTime != nil, moneyline(for: event) != nil {
                games.append(event)
            } else {
                props.append(event)
            }
        }
        return Split(games: games, props: props)
    }

    /// Games grouped by calendar day, days ascending, games within a day by kickoff.
    public static func gamesByDay(_ games: [Event], calendar: Calendar = .current) -> [(day: Date, games: [Event])] {
        let grouped = Dictionary(grouping: games.filter { $0.gameStartTime != nil }) {
            calendar.startOfDay(for: $0.gameStartTime ?? .distantPast)
        }
        return grouped.keys.sorted().map { day in
            (day, grouped[day, default: []].sorted {
                ($0.gameStartTime ?? .distantPast, $0.id) < ($1.gameStartTime ?? .distantPast, $1.id)
            })
        }
    }

    /// The event's moneyline (match winner) market, if any.
    public static func moneyline(for event: Event) -> Market? {
        event.markets.first { $0.sportsMarketType?.lowercased() == "moneyline" }
    }

    /// All moneyline markets of a game. Soccer moneylines are sibling binary markets —
    /// one per team plus a draw — labelled via `groupItemTitle`, priced by their Yes side.
    public static func moneylineMarkets(for event: Event) -> [Market] {
        event.markets.filter { $0.sportsMarketType?.lowercased() == "moneyline" }
    }
}
