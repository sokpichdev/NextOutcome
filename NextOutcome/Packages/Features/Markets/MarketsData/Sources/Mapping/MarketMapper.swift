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
            conditionId: dto.conditionId,
            question: dto.question,
            slug: dto.slug,
            outcomes: outcomes,
            volume: dto.volume,
            liquidity: dto.liquidity,
            endDate: DateParsing.parse(dto.endDateIso),
            isResolved: dto.closed,
            isActive: dto.active,
            imageURL: dto.image.flatMap(URL.init(string:)),
            sportsMarketType: dto.sportsMarketType,
            groupItemTitle: dto.groupItemTitle,
            rules: dto.description)
    }
    
    static func tag(from dto: TagDTO) -> Tag {
        Tag(id: dto.id, label: dto.label, slug: dto.slug)
    }

    static func holders(from groups: [HolderGroupDTO]) -> [Holder] {
        groups.flatMap(\.holders).enumerated().map { index, dto in
            Holder(
                id: dto.proxyWallet ?? "holder-\(index)",
                name: holderName(dto),
                profileImageURL: dto.profileImage.flatMap(URL.init(string:)),
                outcome: outcomeLabel(dto.outcomeIndex),
                shares: dto.amount
            )
        }
        .sorted { $0.shares > $1.shares }
    }

    private static func outcomeLabel(_ index: Int?) -> String {
        switch index {
        case 0: return "Yes"
        case 1: return "No"
        default: return ""
        }
    }

    private static func holderName(_ dto: HolderDTO) -> String {
        if let name = dto.name, !name.isEmpty { return name }
        if let pseudonym = dto.pseudonym, !pseudonym.isEmpty { return pseudonym }
        guard let wallet = dto.proxyWallet, wallet.count > 10 else { return dto.proxyWallet ?? "Anonymous" }
        return "\(wallet.prefix(6))…\(wallet.suffix(4))"
    }

    static func comments(from dtos: [CommentDTO]) -> [Comment] {
        dtos.map { dto in
            Comment(
                id: dto.id,
                authorName: commentAuthorName(dto.profile),
                avatarURL: dto.profile?.profileImage.flatMap { $0.isEmpty ? nil : URL(string: $0) },
                createdAt: DateParsing.parse(dto.createdAt),
                body: dto.body
            )
        }
    }

    private static func commentAuthorName(_ profile: CommentProfileDTO?) -> String {
        if let name = profile?.name, !name.isEmpty { return name }
        if let pseudonym = profile?.pseudonym, !pseudonym.isEmpty { return pseudonym }
        return "Anonymous"
    }

    static func trades(from dtos: [ActivityTradeDTO]) -> [ActivityTrade] {
        dtos.enumerated().map { index, dto in
            ActivityTrade(
                id: dto.transactionHash ?? "trade-\(index)",
                side: dto.side?.uppercased() == "SELL" ? .sell : .buy,
                actorName: tradeActorName(dto),
                outcome: dto.outcome ?? "",
                size: dto.size,
                price: dto.price,
                timestamp: Date(timeIntervalSince1970: dto.timestamp),
                avatarURL: dto.profileImage.flatMap { $0.isEmpty ? nil : URL(string: $0) }
            )
        }
    }

    private static func tradeActorName(_ dto: ActivityTradeDTO) -> String {
        if let name = dto.name, !name.isEmpty { return name }
        if let pseudonym = dto.pseudonym, !pseudonym.isEmpty { return pseudonym }
        guard let wallet = dto.proxyWallet, wallet.count > 10 else { return dto.proxyWallet ?? "Anonymous" }
        return "\(wallet.prefix(6))…\(wallet.suffix(4))"
    }

    static func event(from dto: EventDTO) -> Event {
        Event(
            id: dto.id,
            title: dto.title,
            slug: dto.slug,
            markets: dto.markets.map(market(from:)),
            volume: dto.volume,
            imageURL: dto.image.flatMap(URL.init(string:)),
            tags: dto.tags.map(tag(from:)),
            gameStartTime: DateParsing.parse(dto.gameStartTime),
            description: dto.description
        )
    }
}
