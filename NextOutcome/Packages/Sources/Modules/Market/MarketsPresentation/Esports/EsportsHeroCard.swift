//
//  EsportsHeroCard.swift
//  NextOutcome
//
//  Created by Sok Pich on 14/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// One page of the Esports hub's hero carousel: the live stream (or artwork), the match
/// status line, both team rows with multiplier/percentage/probability bar, the two team
/// buy keys, and the live-trades ticker.
struct EsportsHeroCard: View {
    /// The match event.
    let event: Event
    /// The live result, when loaded.
    let result: GameResult?
    /// The confirmed-live broadcast to embed, if any.
    let stream: EsportsStream?
    /// Recent trades for the ticker, newest first.
    let trades: [ActivityTrade]

    private var info: EsportsMatchInfo { EsportsMatchInfo(event: event, result: result) }

    /// DEBUG-only `-forceTwitchChannel <name>` launch argument, for verifying the embed
    /// plays against a channel that's currently broadcasting.
    static var channelOverride: String? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-forceTwitchChannel"), args.count > index + 1 {
            return args[index + 1]
        }
        #endif
        return nil
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                EsportsStreamView(
                    stream: Self.channelOverride.map { EsportsStream.twitch(channel: $0) } ?? stream,
                    imageURL: event.imageURL
                )
                if result?.live == true {
                    StatusBadge("LIVE", color: DSColor.negative)
                        .padding(DSLayout.spacingSmall)
                }
            }

            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                statusLine
                Text(matchTitleText)
                    .font(DSFont.title)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                teamRow(info.home)
                teamRow(info.away)
                buyRow
            }
            .padding(DSLayout.margin)

            if !trades.isEmpty {
                Divider().overlay(DSColor.surfaceElevated)
                EsportsTradeTicker(trades: trades)
                    .padding(.horizontal, DSLayout.margin)
                    .padding(.vertical, DSLayout.spacingSmall)
            }
        }
        .background(DSColor.surface.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: DSLayout.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DSLayout.cardRadius)
                .strokeBorder(DSColor.surfaceElevated, lineWidth: 1)
        )
    }

    /// "Game 2 of 3 · $88.9K vol · League of Legends", matching web's status strip.
    private var statusLine: some View {
        HStack(spacing: DSLayout.spacingSmall) {
            if result?.live == true {
                Circle().fill(DSColor.negative).frame(width: 6, height: 6)
                Text(EsportsHubViewModel.gameProgressLabel(period: result?.period) ?? "Live")
                    .font(DSFont.caption.bold())
                    .foregroundStyle(DSColor.negative)
            } else if let start = event.gameStartTime {
                Text(start, format: .dateTime.hour().minute())
                    .font(DSFont.caption.bold())
                    .foregroundStyle(DSColor.textSecondary)
            }
            Text("\(MarketFormatting.compactUSD(event.volume)) Vol")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
            if let game = info.game {
                Text(game.fullName)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    /// "LUA Gaming vs FALKE Esports".
    private var matchTitleText: String {
        guard let title = info.title else { return event.title }
        return "\(title.homeTeam) vs \(title.awayTeam)"
    }

    /// One team's row: logo, name, series score, multiplier, % chip, probability bar.
    private func teamRow(_ team: EsportsMatchInfo.Team) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingXSmall) {
            HStack(spacing: DSLayout.spacingMedium) {
                EsportsTeamLogo(url: team.logoURL, name: team.name, size: 34)
                Text(team.name)
                    .font(DSFont.subheadline.bold())
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                Spacer()
                if let score = team.seriesScore, result?.live == true || result?.ended == true {
                    Text("\(score)")
                        .font(DSFont.subheadline.bold())
                        .foregroundStyle(DSColor.textPrimary)
                }
                if let price = team.price, let multiplier = EsportsHubViewModel.multiplier(forPrice: price) {
                    Text(multiplier)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                }
                if let price = team.price {
                    Text(MarketFormatting.percent(price))
                        .font(DSFont.headline.bold())
                        .foregroundStyle(DSColor.textPrimary)
                        .padding(.horizontal, DSLayout.spacingMedium)
                        .padding(.vertical, DSLayout.spacingXSmall)
                        .background(DSColor.surfaceElevated)
                        .clipShape(Capsule())
                }
            }
            if let price = team.price {
                EsportsTeamBar(
                    fraction: NSDecimalNumber(decimal: price).doubleValue,
                    color: Color(hexString: team.colorHex) ?? DSColor.accent
                )
            }
        }
    }

    /// The two team buy keys, tinted with each team's brand colour (blue/red fallback,
    /// matching web's default palette).
    private var buyRow: some View {
        HStack(spacing: DSLayout.spacingSmall) {
            buyButton(info.home, fallback: Color(red: 0.42, green: 0.60, blue: 0.76))
            buyButton(info.away, fallback: Color(red: 0.78, green: 0.42, blue: 0.42))
        }
    }

    @ViewBuilder
    private func buyButton(_ team: EsportsMatchInfo.Team, fallback: Color) -> some View {
        let color = Color(hexString: team.colorHex) ?? fallback
        PriceButton(
            title: team.name,
            price: MarketFormatting.cents(team.price ?? 0),
            style: .solid(color),
            action: {}
        )
        .frame(maxWidth: .infinity)
    }
}

/// A team's circular logo with an initial placeholder, shared by hero and list cards.
struct EsportsTeamLogo: View {
    let url: URL?
    let name: String
    var size: CGFloat = 28

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFit()
        } placeholder: {
            Circle()
                .fill(DSColor.surfaceElevated)
                .overlay(
                    Text(name.prefix(1))
                        .font(DSFont.caption.bold())
                        .foregroundStyle(DSColor.textSecondary)
                )
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

/// A single-colour probability bar in the team's brand colour (web shows one bar per
/// team, filled to its win probability, unlike the green/red binary `ProbabilityBar`).
struct EsportsTeamBar: View {
    /// The filled fraction (0…1).
    let fraction: Double
    /// The bar colour.
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(DSColor.surfaceElevated)
                Capsule()
                    .fill(color)
                    .frame(width: max(6, geo.size.width * max(0, min(1, fraction))))
            }
        }
        .frame(height: 4)
        .animation(.easeInOut(duration: 0.4), value: fraction)
    }
}
