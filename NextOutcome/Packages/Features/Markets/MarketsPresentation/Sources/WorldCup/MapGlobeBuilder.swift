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

    func moved(lat: Double, lon: Double) -> GlobeCountry {
        GlobeCountry(id: id, name: name, abbreviation: abbreviation, lat: lat, lon: lon,
                     percent: percent, colorHex: colorHex)
    }
}

/// Builds the globe's country pills from the tournament-winner market, keeping only nations
/// we have coordinates for.
enum MapGlobeBuilder {
    static func countries(
        from winnerEvent: Event?,
        teams: [String: GameTeam] = [:],
        max: Int = 26
    ) -> [GlobeCountry] {
        guard let winnerEvent else { return [] }
        let raw = winnerEvent.markets
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
        return spaced(Array(raw))
    }

    /// Nudges pills apart so clustered countries (e.g. the Americas along one meridian) don't
    /// overlap on the globe. A few relaxation passes push any pair closer than `minSep` apart
    /// along the line between them, with each pill's total drift bounded so it stays near its
    /// true location. Longitude is scaled by cos(lat) to approximate on-sphere distance.
    static func spaced(_ countries: [GlobeCountry], minSep: Double = 15, maxDrift: Double = 13) -> [GlobeCountry] {
        guard countries.count > 1 else { return countries }
        let original = countries.map { (lat: $0.lat, lon: $0.lon) }
        var pos = original

        for _ in 0..<24 {
            for i in 0..<pos.count {
                for j in (i + 1)..<pos.count {
                    let cosLat = cos((pos[i].lat + pos[j].lat) / 2 * .pi / 180)
                    let dLat = pos[i].lat - pos[j].lat
                    let dLon = (pos[i].lon - pos[j].lon) * cosLat
                    let dist = (dLat * dLat + dLon * dLon).squareRoot()
                    guard dist < minSep, dist > 0.0001 else { continue }
                    let push = (minSep - dist) / 2
                    let ux = dLat / dist, uy = dLon / dist
                    pos[i].lat += ux * push;  pos[i].lon += (uy * push) / max(cosLat, 0.2)
                    pos[j].lat -= ux * push;  pos[j].lon -= (uy * push) / max(cosLat, 0.2)
                }
            }
            // Clamp drift from the true location.
            for i in 0..<pos.count {
                pos[i].lat = clamp(pos[i].lat, around: original[i].lat, by: maxDrift, lo: -85, hi: 85)
                pos[i].lon = clamp(pos[i].lon, around: original[i].lon, by: maxDrift, lo: -180, hi: 180)
            }
        }
        return zip(countries, pos).map { $0.moved(lat: $1.lat, lon: $1.lon) }
    }

    private static func clamp(_ v: Double, around origin: Double, by drift: Double, lo: Double, hi: Double) -> Double {
        min(max(min(max(v, origin - drift), origin + drift), lo), hi)
    }
}
