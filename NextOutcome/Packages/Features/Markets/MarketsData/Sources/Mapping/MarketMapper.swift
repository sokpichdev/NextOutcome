//
//  MarketMapper.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation
import MarketsDomain

/// Translates the Gamma DTOs into clean domain types (markets, events, tags, holders,
/// comments, trades), zipping the parallel outcome/price/token arrays together and building
/// friendly display names. Keeping all this in one place means the domain never sees the
/// API's quirky wire shape.
enum MarketMapper {
    /// Maps a `MarketDTO` to a domain `Market`, zipping outcome labels with their prices and
    /// token ids (falling back to a synthesized id when the token array is short).
    /// - Parameter dto: The decoded market.
    /// - Returns: The domain market.
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
            endDate: DateParsing.parse(dto.endDate),
            isResolved: dto.closed,
            isActive: dto.active,
            imageURL: dto.image.flatMap(URL.init(string:)),
            sportsMarketType: dto.sportsMarketType,
            groupItemTitle: dto.groupItemTitle,
            rules: dto.description)
    }
    
    /// Maps a `TagDTO` to a domain `Tag`.
    static func tag(from dto: TagDTO) -> Tag {
        Tag(id: dto.id, label: dto.label, slug: dto.slug)
    }

    /// Maps a `MoverDTO` to a domain `Mover`, resolving the current probability (first outcome
    /// price, falling back to the last trade) and pulling the parent event's slug/title/icon.
    /// - Parameter dto: The decoded `/markets` row.
    /// - Returns: The domain mover.
    static func mover(from dto: MoverDTO) -> Mover {
        let parent = dto.events.first
        let probability = dto.outcomePrices.first ?? dto.lastTradePrice ?? 0
        let imageString = parent?.image ?? parent?.icon ?? dto.image ?? dto.icon
        return Mover(
            id: dto.id,
            question: dto.question,
            eventSlug: parent?.slug ?? "",
            eventTitle: parent?.title ?? dto.question,
            imageURL: imageString.flatMap(URL.init(string:)),
            probability: probability,
            dayChange: dto.oneDayPriceChange,
            volume24h: dto.volume24hr
        )
    }

    /// Flattens the grouped holder DTOs into a single list of domain `Holder`s, sorted by
    /// shares held (largest first).
    /// - Parameter groups: The per-outcome holder groups.
    /// - Returns: The domain holders, highest shares first.
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

    /// Maps a numeric outcome index to a "Yes"/"No" label (empty for anything else).
    private static func outcomeLabel(_ index: Int?) -> String {
        switch index {
        case 0: return "Yes"
        case 1: return "No"
        default: return ""
        }
    }

    /// Picks a holder display name: real name, then pseudonym, then a shortened wallet.
    private static func holderName(_ dto: HolderDTO) -> String {
        if let name = dto.name, !name.isEmpty { return name }
        if let pseudonym = dto.pseudonym, !pseudonym.isEmpty { return pseudonym }
        guard let wallet = dto.proxyWallet, wallet.count > 10 else { return dto.proxyWallet ?? "Anonymous" }
        return "\(wallet.prefix(6))…\(wallet.suffix(4))"
    }

    /// Maps comment DTOs to domain `Comment`s, resolving author names and avatars.
    /// - Parameter dtos: The decoded comments.
    /// - Returns: The domain comments.
    static func comments(from dtos: [CommentDTO]) -> [Comment] {
        dtos.map { dto in
            Comment(
                id: dto.id,
                authorName: commentAuthorName(dto.profile),
                avatarURL: dto.profile?.profileImage.flatMap { $0.isEmpty ? nil : URL(string: $0) },
                createdAt: DateParsing.parse(dto.createdAt),
                body: dto.body,
                likeCount: dto.reactionCount,
                proxyWallet: dto.profile?.proxyWallet.flatMap { $0.isEmpty ? nil : $0 }
            )
        }
    }

    /// Maps comment-holding DTOs to domain `CommentHolding`s, dropping rows with no
    /// resolvable condition id (malformed/partial data).
    /// - Parameter dtos: The decoded positions.
    /// - Returns: The domain holdings.
    static func commentHoldings(from dtos: [CommentHoldingDTO]) -> [CommentHolding] {
        dtos.filter { !$0.conditionId.isEmpty }.map {
            CommentHolding(conditionId: $0.conditionId, outcome: $0.outcome, size: $0.size)
        }
    }

    /// Picks a comment author name: real name, then pseudonym, then "Anonymous".
    private static func commentAuthorName(_ profile: CommentProfileDTO?) -> String {
        if let name = profile?.name, !name.isEmpty { return name }
        if let pseudonym = profile?.pseudonym, !pseudonym.isEmpty { return pseudonym }
        return "Anonymous"
    }

    /// Maps trade DTOs to domain `ActivityTrade`s, resolving side, actor name, and avatar.
    /// - Parameter dtos: The decoded trades.
    /// - Returns: The domain trades.
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

    /// Picks a trade actor name: real name, then pseudonym, then a shortened wallet.
    private static func tradeActorName(_ dto: ActivityTradeDTO) -> String {
        if let name = dto.name, !name.isEmpty { return name }
        if let pseudonym = dto.pseudonym, !pseudonym.isEmpty { return pseudonym }
        guard let wallet = dto.proxyWallet, wallet.count > 10 else { return dto.proxyWallet ?? "Anonymous" }
        return "\(wallet.prefix(6))…\(wallet.suffix(4))"
    }

    /// Maps an `EventDTO` to a domain `Event`, recursively mapping its markets and tags.
    ///
    /// Gamma's `/events` responses never actually carry `gameStartTime` on the event itself —
    /// only on its embedded markets. `dto.gameStartTime` decodes tolerantly and stays nil in
    /// practice, so every sports event falls back to the earliest kickoff among its markets.
    /// Without this, `Event.gameStartTime` is nil for every event fetched by tag (the Sports
    /// hub's Live feed and every league detail screen), so `WorldCupEventSplitter.split`
    /// (which requires a kickoff to classify something as a schedulable "game") buckets real
    /// games — MLB, UFC, etc. — as props instead, leaving the Games tab empty.
    /// - Parameter dto: The decoded event.
    /// - Returns: The domain event.
    static func event(from dto: EventDTO) -> Event {
        let markets = dto.markets.map(market(from:))
        let eventKickoff = DateParsing.parse(dto.gameStartTime)
        let earliestMarketKickoff = dto.markets.compactMap { DateParsing.parse($0.gameStartTime) }.min()
        return Event(
            id: dto.id,
            title: dto.title,
            slug: dto.slug,
            markets: markets,
            volume: dto.volume,
            imageURL: dto.image.flatMap(URL.init(string:)),
            tags: dto.tags.map(tag(from:)),
            gameStartTime: eventKickoff ?? earliestMarketKickoff,
            description: dto.description
        )
    }
}
