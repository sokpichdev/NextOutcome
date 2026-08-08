//
//  PolymarketService.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

/// Identifies which of Polymarket's separate backend services an `Endpoint` should
/// call. Polymarket splits its API across several hosts by responsibility rather
/// than exposing one single API host, so every `Endpoint` needs to say which one
/// it's targeting.
public enum PolymarketService {
    /// Serves market/event metadata (titles, descriptions, tags, images, rules).
    /// Used for most read-only "what markets exist" queries.
    case gamma

    /// Serves activity, positions, holders, and leaderboard data — i.e. what
    /// wallets have done and are currently holding.
    case data

    /// The Central Limit Order Book service: live order books, trade history,
    /// and order submission/cancellation.
    case clob

    /// Used to check whether the current user's region is blocked from trading,
    /// per Polymarket's geographic restrictions.
    case geoblock

    /// The main polymarket.com web app's own Next.js API routes (distinct from the
    /// dedicated Gamma/Data/CLOB backends) — e.g. `/api/crypto/*`, used for real BTC
    /// spot-price data that isn't exposed anywhere else.
    case web

    /// The hostname to use when building a request to this service, without a
    /// scheme (`https://` is added separately by `Endpoint.urlRequest`).
    var baseURL: String {
        switch self {
        case .gamma: return "gamma-api.polymarket.com"
        case .data: return "data-api.polymarket.com"
        case .clob: return "clob.polymarket.com"
        case .geoblock: return "polymarket.com"
        case .web: return "polymarket.com"
        }
    }
}
