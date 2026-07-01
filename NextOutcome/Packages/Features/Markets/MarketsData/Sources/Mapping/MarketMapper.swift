//
//  MarketMapper.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation
import MarketsDomain

enum MarketMapper {
    static func market(from dto: MarketDTO) -> Market {
        let outcomes = dto.outcomes.enumerated().map { index, name in
            Outcome(
                id: index < dto.clobTokenIds.count ? dto.clobTokenIds[index] : "\(dto.id)-\(index)",
                title: name,
                price: index < dto.outcomePrices.count ? dto.outcomePrices[index] : 0,
                isWinner: nil
            )
        }
        return Market(
            id: dto.id,
            question: dto.question,
            slug: dto.slug,
            outcomes: outcomes,
            volume: dto.volume,
            liquidity: dto.liquidity,
            endDate: DateParsing.parse(dto.endDateIso),
            isResolved: dto.closed,
            imageURL: dto.image.flatMap(URL.init(string:)))
    }
    
    static func tag(from dto: TagDTO) -> Tag {
        Tag(id: dto.id, label: dto.label, slug: dto.slug)
    }

    static func event(from dto: EventDTO) -> Event {
        Event(
            id: dto.id,
            title: dto.title,
            slug: dto.slug,
            markets: dto.markets.map(market(from:)),
            volume: dto.volume,
            imageURL: dto.image.flatMap(URL.init(string:))
        )
    }
}
