import SwiftUI
import MarketsDomain
import DesignSystem

/// The two sides a trader can take on a market. Placeholder for Task 8's trade sheet, which
/// consumes `MarketGroupSection`'s `onSelect(Market, Side)` hook.
public enum Side {
    case yes
    case no
}

/// A titled section of an event's markets, grouped per `MarketGroupClassifier`
/// (Moneyline, Spreads, Totals, …). Each row shows the outcome label, its chance %,
/// and two `PriceButton`s. Tapping a price button fires `onSelect`; tapping the rest
/// of the row pushes `MarketDetailView` via `NavigationLink(value: market)`.
public struct MarketGroupSection: View {
    private let group: MarketGroup
    private let markets: [Market]
    private let eventID: String
    private let onSelect: (Market, Side) -> Void

    public init(group: MarketGroup, markets: [Market], eventID: String, onSelect: @escaping (Market, Side) -> Void = { _, _ in }) {
        self.group = group
        self.markets = markets
        self.eventID = eventID
        self.onSelect = onSelect
    }

    public var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                Text(group.title)
                    .font(DSFont.subheadline.bold())
                    .foregroundStyle(DSColor.textPrimary)
                ForEach(Array(markets.enumerated()), id: \.element.id) { index, market in
                    row(for: market)
                    if index < markets.count - 1 {
                        Divider().overlay(DSColor.separator)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(for market: Market) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
            NavigationLink(value: MarketNavigationTarget(market: market, eventID: eventID)) {
                HStack {
                    Text(rowTitle(market))
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.textPrimary)
                        .lineLimit(2)
                    Spacer()
                    if let yes = market.yesOutcome {
                        Text(MarketFormatting.percent(yes.price))
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: DSLayout.spacingSmall) {
                if let yes = market.yesOutcome {
                    PriceButton(title: yes.title, price: cents(yes.price), style: .yes) {
                        onSelect(market, .yes)
                    }
                }
                if let no = market.noOutcome {
                    PriceButton(title: no.title, price: cents(no.price), style: .no) {
                        onSelect(market, .no)
                    }
                }
            }
        }
    }

    private func rowTitle(_ market: Market) -> String {
        market.groupItemTitle ?? market.question
    }

    private func cents(_ price: Decimal) -> String {
        MarketFormatting.percent(price).replacingOccurrences(of: "%", with: "¢")
    }
}

#if DEBUG
private func _mkt(_ groupTitle: String, _ yes: Double, sportsType: String) -> Market {
    Market(id: groupTitle, question: "\(groupTitle) moneyline", slug: groupTitle,
           outcomes: [Outcome(id: "y", title: "Yes", price: Decimal(yes)),
                      Outcome(id: "n", title: "No", price: Decimal(1 - yes))],
           volume: 0, liquidity: 0, endDate: nil, isResolved: false, imageURL: nil,
           sportsMarketType: sportsType, groupItemTitle: groupTitle)
}

#Preview("Market group section") {
    NavigationStack {
        ScrollView {
            MarketGroupSection(
                group: .moneyline,
                markets: [_mkt("Argentina", 0.86, sportsType: "moneyline"),
                          _mkt("Cabo Verde", 0.043, sportsType: "moneyline")],
                eventID: "preview-event"
            )
            .padding()
        }
        .background(DSColor.background)
    }
}
#endif
