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
    /// Resolved (eliminated) outcomes are collapsed behind a toggle to keep the tradeable
    /// list clean — matching the live site's "Hide resolved" section.
    @State private var showResolved = false

    public init(group: MarketGroup, markets: [Market], eventID: String, onSelect: @escaping (Market, Side) -> Void = { _, _ in }) {
        self.group = group
        self.markets = markets
        self.eventID = eventID
        self.onSelect = onSelect
    }

    /// Settled outcomes (eliminated teams etc.) — hidden until the user expands them.
    private var resolvedMarkets: [Market] { markets.filter { $0.isResolved } }
    /// Still-tradeable outcomes (shown with Buy buttons). A country that already appears in
    /// the resolved list is excluded here so it doesn't show twice (some events carry both a
    /// closed and a stale open market for the same outcome).
    private var activeMarkets: [Market] {
        let resolvedKeys = Set(resolvedMarkets.map(outcomeKey))
        // `isActive` drops undetermined placeholder slots (e.g. "Team AG") that carry no
        // prices and aren't tradeable yet — matching what the live site lists.
        return markets.filter { $0.isActive && !$0.isResolved && !resolvedKeys.contains(outcomeKey($0)) }
    }

    /// Identity used to de-duplicate the same outcome across the active/resolved buckets.
    private func outcomeKey(_ market: Market) -> String {
        (market.groupItemTitle ?? market.question).lowercased()
    }

    public var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                Text(group.title)
                    .font(DSFont.subheadline.bold())
                    .foregroundStyle(DSColor.textPrimary)
                ForEach(Array(activeMarkets.enumerated()), id: \.element.id) { index, market in
                    row(for: market)
                    if index < activeMarkets.count - 1 {
                        Divider().overlay(DSColor.separator)
                    }
                }
                if !resolvedMarkets.isEmpty {
                    Divider().overlay(DSColor.separator)
                    resolvedToggle
                    if showResolved {
                        ForEach(resolvedMarkets) { market in
                            Divider().overlay(DSColor.separator)
                            resolvedRow(for: market)
                        }
                    }
                }
            }
        }
    }

    private var resolvedToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { showResolved.toggle() }
        } label: {
            HStack(spacing: DSLayout.spacingXSmall) {
                Text(showResolved ? "Hide resolved" : "Show resolved (\(resolvedMarkets.count))")
                    .font(DSFont.subheadline.bold())
                    .foregroundStyle(DSColor.textSecondary)
                Image(systemName: showResolved ? "chevron.up" : "chevron.down")
                    .font(DSFont.caption.bold())
                    .foregroundStyle(DSColor.textSecondary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    /// A settled outcome: flag + name + volume, and the winning side badged (green ✓ for
    /// a Yes resolution, red ✕ for No). No trade buttons — the market is closed.
    @ViewBuilder
    private func resolvedRow(for market: Market) -> some View {
        NavigationLink(value: MarketNavigationTarget(market: market, eventID: eventID)) {
            HStack {
                CardIcon(url: market.imageURL)
                VStack(alignment: .leading, spacing: 2) {
                    Text(rowTitle(market))
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.textPrimary)
                        .lineLimit(1)
                    Text("\(MarketFormatting.compactUSD(market.volume)) Vol.")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                }
                Spacer()
                if let winner = resolvedOutcome(market) {
                    HStack(spacing: DSLayout.spacingXSmall) {
                        Text(winner.title)
                            .font(DSFont.subheadline.bold())
                            .foregroundStyle(DSColor.textSecondary)
                        Image(systemName: winner.title == "Yes" ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(winner.title == "Yes" ? DSColor.positive : DSColor.negative)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// The winning outcome of a settled market — the one that resolved to ~1.0. `Outcome`
    /// carries no `isWinner` from Gamma, so we infer it from the highest price.
    private func resolvedOutcome(_ market: Market) -> Outcome? {
        market.outcomes.max { $0.price < $1.price }
    }

    @ViewBuilder
    private func row(for market: Market) -> some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
            NavigationLink(value: MarketNavigationTarget(market: market, eventID: eventID)) {
                HStack {
                    CardIcon(url: market.imageURL)
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
                    PriceButton(title: "Buy \(yes.title)", price: MarketFormatting.cents(yes.price), style: .yes) {
                        onSelect(market, .yes)
                    }
                }
                if let no = market.noOutcome {
                    PriceButton(title: "Buy \(no.title)", price: MarketFormatting.cents(no.price), style: .no) {
                        onSelect(market, .no)
                    }
                }
            }
        }
    }

    private func rowTitle(_ market: Market) -> String {
        market.groupItemTitle ?? market.question
    }
}

#if DEBUG
private func _mkt(_ groupTitle: String, _ yes: Double, sportsType: String, resolved: Bool = false, volume: Decimal = 0) -> Market {
    Market(id: groupTitle, question: "\(groupTitle) moneyline", slug: groupTitle,
           outcomes: [Outcome(id: "y", title: "Yes", price: Decimal(yes)),
                      Outcome(id: "n", title: "No", price: Decimal(1 - yes))],
           volume: volume, liquidity: 0, endDate: nil, isResolved: resolved,
           imageURL: URL(string: "https://example.com/flag.png"),
           sportsMarketType: sportsType, groupItemTitle: groupTitle)
}

#Preview("Market group section") {
    NavigationStack {
        ScrollView {
            MarketGroupSection(
                group: .moneyline,
                markets: [_mkt("Argentina", 0.86, sportsType: "moneyline"),
                          _mkt("Cabo Verde", 0.043, sportsType: "moneyline"),
                          _mkt("New Zealand", 0.0, sportsType: "moneyline", resolved: true, volume: 47_529_247),
                          _mkt("South Korea", 0.0, sportsType: "moneyline", resolved: true, volume: 107_521_229)],
                eventID: "preview-event"
            )
            .padding()
        }
        .background(DSColor.background)
    }
}
#endif
