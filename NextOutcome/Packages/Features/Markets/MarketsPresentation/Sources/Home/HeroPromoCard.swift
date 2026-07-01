import SwiftUI
import MarketsDomain
import DesignSystem

/// Large promo tile (e.g. "World Cup Odds & Predictions") with tilted outcome tiles.
public struct HeroPromoCard: View {
    private let event: Event
    public init(event: Event) { self.event = event }

    private var topMarkets: [Market] { Array(event.markets.prefix(5)) }

    public var body: some View {
        NavigationLink(value: event) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 16).fill(DSColor.surface)
                HStack(spacing: -12) {
                    ForEach(Array(topMarkets.enumerated()), id: \.offset) { idx, market in
                        VStack(spacing: 4) {
                            CardIcon(url: market.imageURL)
                            if let yes = market.yesOutcome {
                                Text(MarketFormatting.percent(yes.price))
                                    .font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
                            }
                        }
                        .rotationEffect(.degrees(Double(idx - 2) * 8))
                    }
                }
                .padding(.trailing, 24)
                .frame(maxWidth: .infinity, alignment: .trailing)

                Text(event.title)
                    .font(DSFont.title).foregroundStyle(DSColor.textPrimary)
                    .lineLimit(2).padding(16)
            }
            .frame(height: 180)
        }
        .buttonStyle(.plain)
    }
}
