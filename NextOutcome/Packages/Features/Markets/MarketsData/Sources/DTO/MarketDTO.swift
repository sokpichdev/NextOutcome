//
//  MarketDTO.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation
import Networking

struct TokenDTO: Decodable {
    let tokenId: String
    let outcome: String
    let price: DecimalString
    let winner: Bool?
}

struct MarketDTO: Decodable {
    let id: String
    let question: String
    let marketSlug: String
    let tokens: [TokenDTO]
    let volume: DecimalString
    let liquidity: DecimalString
    let endDateIso: String?
    let closed: Bool
    let image: String?
}

struct EventDTO: Decodable {
    let id: String
    let title: String
    let slug: String
    let markets: [MarketDTO]
    let volume: DecimalString
    let image: String?
}

struct EventsEnvelope: Decodable {
    let data: [EventDTO]
    let nextCursor: String?
}
