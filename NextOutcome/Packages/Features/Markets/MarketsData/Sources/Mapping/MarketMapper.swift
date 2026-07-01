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
        Market(
            id: dto.id,
            question: dto.question,
            slug: dto.marketSlug,
            outcomes: dto.tokens.map { token in
                Outcome(
                    id: token.tokenId,
                    title: token.outcome,
                    price: token.price.wrappedValue,
                    isWinner: token.winner)
            },
            volume: dto.volume.wrappedValue,
            liquidity: dto.liquidity.wrappedValue,
            endDate: DateParsing.parse(dto.endDateIso),
            isResolved: dto.closed,
            imageURL: dto.image.flatMap(URL.init(string: )))
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
            volume: dto.volume.wrappedValue,
            imageURL: dto.image.flatMap(URL.init(string:))
        )
    }
}
