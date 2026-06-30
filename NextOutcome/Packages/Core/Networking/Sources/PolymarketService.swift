//
//  PolymarketService.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

public enum PolymarketService {
    case gamma
    case data
    case clob
    case geoblock
    
    var baseURL: String {
        switch self {
        case .gamma: return "gamma-api.polymarket.com"
        case .data: return "data-api.polymarket.com"
        case .clob: return "clob.polymarket.com"
        case .geoblock: return "polymarket.com"
        }
    }
}
