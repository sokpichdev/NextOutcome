import SwiftUI
import MarketsDomain
import DesignSystem

/// Event with several sub-markets (e.g. "World Cup Winner"): top outcome rows + volume + actions.
public struct MultiOutcomeCard: View {
    /// The event with several sub-markets.
    private let event: Event
    /// Creates the card.
    /// - Parameter event: The event to display.
    public init(event: Event) { self.event = event }

    /// The two likeliest sub-markets, most probable first.
    ///
    /// A preview, not the full list — the event detail screen is where every sub-market is
    /// listed. Two rows keeps a feed of these cards scannable and matches `CryptoStrikeCard`,
    /// which shows the same number for the same reason.
    ///
    /// Ranking by probability is what makes those two rows worth showing. Gamma returns an
    /// event's markets in its own configuration order, not by price, so a plain `prefix`
    /// surfaced whichever options happened to be listed first — routinely the *least* likely
    /// ones. "Fed Decision in September?" led with `50+ bps decrease` at 0.5% and `25 bps
    /// decrease` at 1.3% while hiding `No change` at 66%. Same ranking `FuturesOddsCard`
    /// applies for the same reason.
    ///
    /// Sorted on `primaryOutcome`, not `yesOutcome`: team-named markets have no Yes side and
    /// would all rank as 0. The sort is made stable by the index tiebreak so equally-priced
    /// rows — a date ladder where every option sits at 0% — keep Gamma's order rather than an
    /// arbitrary one that could reshuffle between renders.
    private var topMarkets: [Market] {
        event.markets
            .enumerated()
            .sorted { lhs, rhs in
                let lp = lhs.element.primaryOutcome?.price ?? 0
                let rp = rhs.element.primaryOutcome?.price ?? 0
                return lp == rp ? lhs.offset < rhs.offset : lp > rp
            }
            .prefix(2)
            .map(\.element)
    }

    public var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                HStack(spacing: DSLayout.spacing) {
                    CardIcon(url: event.imageURL)
                    Text(event.title).font(DSFont.headline)
                        .foregroundStyle(DSColor.textPrimary).lineLimit(1)
                    Spacer()
                    EventStatusBadge(event: event)
                }
                ForEach(topMarkets) { market in
                    NavigationLink(value: MarketNavigationTarget(market: market, eventID: event.id)) {
                        HStack {
                            Text(market.groupItemTitle ?? market.question).font(DSFont.subheadline)
                                .foregroundStyle(DSColor.textPrimary).lineLimit(1)
                            Spacer()
                            if let yes = market.yesOutcome {
                                Text(MarketFormatting.percent(yes.price))
                                    .font(DSFont.priceSmall).foregroundStyle(DSColor.textPrimary)
                                OutcomePill(.yes)
                                OutcomePill(.no)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                HStack {
                    Text("\(MarketFormatting.compactUSD(event.volume)) Vol.")
                        .font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                    Image(systemName: "gift")
                    Image(systemName: "bookmark")
                }
                .foregroundStyle(DSColor.textSecondary)
            }
        }
    }
}

/// Shared rounded market/event icon used by the Home cards.
struct CardIcon: View {
    /// The image URL, or `nil` to show a plain placeholder.
    let url: URL?
    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { DSColor.surfaceElevated }
            } else { DSColor.surfaceElevated }
        }
        .frame(width: DSLayout.iconsize, height: DSLayout.iconsize)
        .clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
    }
}
