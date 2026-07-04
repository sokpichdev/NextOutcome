//
//  WorldCupTab.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

/// Sub-tabs of the World Cup hub. Bracket and Map render placeholders until their data
/// views land; adding one means replacing a single switch case in `WorldCupHubView`.
public enum WorldCupTab: String, CaseIterable, Sendable {
    case games, props, bracket, map

    public var title: String {
        switch self {
        case .games:   return "Games"
        case .props:   return "Props"
        case .bracket: return "Bracket"
        case .map:     return "Map"
        }
    }
}
