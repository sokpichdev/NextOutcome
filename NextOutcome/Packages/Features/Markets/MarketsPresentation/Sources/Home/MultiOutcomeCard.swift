import SwiftUI
import MarketsDomain
import DesignSystem

/// Event with several sub-markets (e.g. "World Cup Winner"): top outcome rows + volume + actions.
public struct MultiOutcomeCard: View {
    private let event: Event
    public init(event: Event) { self.event = event }

    private var topMarkets: [Market] { Array(event.markets.prefix(3)) }

    public var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                HStack(spacing: DSLayout.spacing) {
                    CardIcon(url: event.imageURL)
                    Text(event.title).font(DSFont.headline)
                        .foregroundStyle(DSColor.textPrimary).lineLimit(1)
                    Spacer()
                }
                ForEach(topMarkets) { market in
                    NavigationLink(value: market) {
                        HStack {
                            Text(market.question).font(DSFont.subheadline)
                                .foregroundStyle(DSColor.textPrimary).lineLimit(1)
                            Spacer()
                            if let yes = market.yesOutcome {
                                Text(MarketFormatting.percent(yes.price))
                                    .font(DSFont.priceSmall).foregroundStyle(DSColor.textPrimary)
                                OutcomePill(.yes, value: "Yes")
                                OutcomePill(.no, value: "No")
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
