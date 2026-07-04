//
//  MapGlobeBuilder.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import Foundation
import MarketsDomain

/// A country to place on the globe: where it sits, its win %, and its pill styling.
struct GlobeCountry: Identifiable, Equatable {
    let id: String
    let name: String
    let abbreviation: String
    let lat: Double
    let lon: Double
    let percent: Double // 0…1
    let colorHex: String?

    /// "35%" / "<1%".
    var caption: String {
        percent < 0.01 ? "<1%" : MarketFormatting.percent(Decimal(percent))
    }
}

/// Builds the globe's country pills from the tournament-winner market, keeping only nations
/// we have coordinates for.
enum MapGlobeBuilder {
    static func countries(
        from winnerEvent: Event?,
        teams: [String: GameTeam] = [:],
        max: Int = 40
    ) -> [GlobeCountry] {
        guard let winnerEvent else { return [] }
        return winnerEvent.markets
            .filter { $0.isActive && $0.yesOutcome != nil }
            .compactMap { market -> GlobeCountry? in
                let name = market.groupItemTitle ?? market.question
                guard let loc = CountryCoordinates.location(for: name) else { return nil }
                let team = teams[name.lowercased()]
                return GlobeCountry(
                    id: market.id,
                    name: name,
                    abbreviation: team?.abbreviation ?? String(name.prefix(3)).uppercased(),
                    lat: loc.lat,
                    lon: loc.lon,
                    percent: NSDecimalNumber(decimal: market.yesOutcome?.price ?? 0).doubleValue,
                    colorHex: team?.colorHex
                )
            }
            .sorted { $0.percent > $1.percent }
            .prefix(max)
            .map { $0 }
    }
}
