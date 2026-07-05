//
//  CountryCoordinates.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import Foundation

/// Approximate (latitude, longitude) for nations that appear in World Cup markets, used to
/// anchor their pills on the globe. Keyed by lowercased name; aliases cover feed spellings.
enum CountryCoordinates {
    /// Looks up a nation's approximate coordinates by name (case/whitespace-insensitive).
    /// - Parameter name: The nation name (feed spelling).
    /// - Returns: The `(lat, lon)` pair, or `nil` if the nation isn't in the table.
    static func location(for name: String) -> (lat: Double, lon: Double)? {
        table[normalize(name)]
    }

    /// Lowercases and trims a name to match the table's keys.
    private static func normalize(_ name: String) -> String {
        name.lowercased().trimmingCharacters(in: .whitespaces)
    }

    /// The lookup table of nation → approximate `(latitude, longitude)`; aliases cover
    /// alternate feed spellings (e.g. "usa"/"united states").

    private static let table: [String: (lat: Double, lon: Double)] = [
        "argentina": (-38.4, -63.6), "australia": (-25.3, 133.8), "austria": (47.5, 14.6),
        "belgium": (50.5, 4.5), "bosnia and herzegovina": (43.9, 17.7), "brazil": (-14.2, -51.9),
        "cabo verde": (16.0, -24.0), "cape verde": (16.0, -24.0), "cameroon": (7.4, 12.4),
        "canada": (56.1, -106.3), "chile": (-35.7, -71.5), "colombia": (4.6, -74.3),
        "costa rica": (9.7, -83.8), "croatia": (45.1, 15.2), "czechia": (49.8, 15.5),
        "czech republic": (49.8, 15.5), "denmark": (56.3, 9.5), "ecuador": (-1.8, -78.2),
        "egypt": (26.8, 30.8), "england": (52.4, -1.5), "france": (46.2, 2.2),
        "germany": (51.2, 10.5), "ghana": (7.9, -1.0), "haiti": (18.9, -72.3),
        "iran": (32.4, 53.7), "iraq": (33.2, 43.7), "italy": (41.9, 12.6),
        "japan": (36.2, 138.3), "jordan": (30.6, 36.2), "korea republic": (35.9, 127.8),
        "south korea": (35.9, 127.8), "mexico": (23.6, -102.6), "morocco": (31.8, -7.1),
        "netherlands": (52.1, 5.3), "nigeria": (9.1, 8.7), "norway": (60.5, 8.5),
        "paraguay": (-23.4, -58.4), "peru": (-9.2, -75.0), "poland": (51.9, 19.1),
        "portugal": (39.4, -8.2), "qatar": (25.4, 51.2), "saudi arabia": (23.9, 45.1),
        "senegal": (14.5, -14.5), "serbia": (44.0, 21.0), "south africa": (-30.6, 22.9),
        "spain": (40.5, -3.7), "sweden": (60.1, 18.6), "switzerland": (46.8, 8.2),
        "tunisia": (33.9, 9.5), "türkiye": (38.9, 35.2), "turkey": (38.9, 35.2),
        "united states": (37.1, -95.7), "usa": (37.1, -95.7), "uruguay": (-32.5, -55.8),
        "wales": (52.1, -3.8),
    ]
}
