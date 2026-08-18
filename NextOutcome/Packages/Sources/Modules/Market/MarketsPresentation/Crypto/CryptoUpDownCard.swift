import SwiftUI
import MarketsDomain
import DesignSystem
import OrderbookPresentation

/// Crypto-hub-scoped variant of `LiveUpDownCard`: same gauge/Up-Down visual, but tapping
/// the whole card navigates to the rich `BTCLiveView` screen instead of the generic
/// `MarketDetailView`. `LiveUpDownCard` itself is untouched — it's also used by the Home
/// feed (`HomeCard.swift`), and changing its navigation there is out of scope for this
/// slice. Unlike `LiveUpDownCard`'s hardcoded "LIVE · Bitcoin" footer, this card derives
/// the real coin name from `event.tags` (same approach as `CryptoStrikeCard.coinLabel`).
public struct CryptoUpDownCard: View {
    /// The event backing the card.
    private let event: Event
    /// Factory (from the environment) for building the live-market view model.
    @Environment(\.marketLiveFactory) private var factory
    /// The live view model, created lazily once a factory and Up outcome are available.
    @State private var model: LiveUpDownCardViewModel?

    /// Creates the card.
    /// - Parameter event: The event to display.
    public init(event: Event) { self.event = event }

    /// The name to show. A live Up/Down card re-points at a new window every few minutes, so
    /// the per-window event title (`"Bitcoin Up or Down - August 3, 10:15AM-10:20AM ET"`) is
    /// both too long for the card and stale the moment the window rolls. The series name
    /// (`"BTC Up or Down 5m"`) is what the card actually represents, and what Polymarket
    /// shows. Falls back to the event title for anything without a series.
    private var cardTitle: String {
        event.seriesTitle ?? event.title
    }

    /// The event's first market.
    private var market: Market? { event.markets.first }
    /// The "Up" outcome, if the market has one.
    private var upOutcome: Outcome? {
        market?.outcomes.first { $0.title.lowercased() == "up" }
    }
    /// The navigation target opened when the card is tapped. `nil` (and thus the card
    /// isn't navigable) only if the event has no markets or no "Up" outcome — shouldn't
    /// happen for a `.upDown`-classified event in practice, since `CryptoMarketKind`
    /// already checks for Up/Down outcomes before classifying an event this way.
    private var navigationTarget: CryptoUpDownNavigationTarget? {
        guard let market, let upOutcome else { return nil }
        return CryptoUpDownNavigationTarget(
            assetID: upOutcome.id, eventID: event.id,
            windowEnd: market.endDate ?? .distantFuture,
            symbol: Self.coinSymbol(for: event),
            windowInterval: Self.windowInterval(for: event),
            // The same series name the card shows, for the same reason: the per-window
            // event title is stale the moment the window rolls.
            title: cardTitle,
            iconURL: event.imageURL,
            market: market
        )
    }

    public var body: some View {
        NavigationLink(value: navigationTarget) {
            DSCard {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: DSLayout.spacing) {
                            CardIcon(url: event.imageURL)
                            Text(cardTitle).font(DSFont.headline)
                                .foregroundStyle(DSColor.textPrimary).lineLimit(1)
                        }
                        HStack {
                            Text("Up").frame(maxWidth: .infinity)
                                .font(DSFont.headline).foregroundStyle(.white)
                                .padding(.vertical, 14)
                                .background(DSGradient.positive)
                                .clipShape(RoundedRectangle(cornerRadius: DSLayout.pillRadius))
                            Text("Down").frame(maxWidth: .infinity)
                                .font(DSFont.headline).foregroundStyle(.white)
                                .padding(.vertical, 14)
                                .background(DSGradient.negative)
                                .clipShape(RoundedRectangle(cornerRadius: DSLayout.pillRadius))
                        }
                        Label("LIVE · \(Self.coinLabel(for: event))", systemImage: "circle.fill")
                            .font(DSFont.caption).foregroundStyle(DSColor.negative)
                    }
                    Spacer()
                    gauge
                }
            }
        }
        .buttonStyle(.plain)
        .task {
            if model == nil, let up = upOutcome, let f = factory {
                model = LiveUpDownCardViewModel(upOutcome: up, factory: f)
            }
            model?.start()
        }
        .onDisappear { model?.stop() }
    }

    /// The semicircular Up% gauge, filled to the live (or fallback static) Up fraction.
    /// Identical to `LiveUpDownCard`'s gauge.
    @ViewBuilder
    private var gauge: some View {
        let fraction = model?.upFraction ?? upOutcome.map { NSDecimalNumber(decimal: $0.price).doubleValue } ?? 0.5
        ZStack {
            Circle().trim(from: 0, to: 0.5).rotation(.degrees(180))
                .stroke(DSColor.separator, style: .init(lineWidth: 6, lineCap: .round))
            Circle().trim(from: 0, to: fraction * 0.5).rotation(.degrees(180))
                .stroke(DSColor.positive, style: .init(lineWidth: 6, lineCap: .round))
            Text(model?.upPercentText ?? "—")
                .font(DSFont.headline).foregroundStyle(DSColor.textPrimary)
        }
        .frame(width: 72, height: 72)
    }

    /// Known coin tag slugs, mapped to their display label, matched against `event.tags`.
    /// Same table as `CryptoStrikeCard.coinLabels` — small enough that duplicating it here
    /// (rather than sharing a type across two small, single-purpose card files) is the
    /// simpler tradeoff.
    private static let coinLabels: [String: String] = [
        "bitcoin": "Bitcoin", "ethereum": "Ethereum", "solana": "Solana",
        "xrp": "XRP", "dogecoin": "Dogecoin", "bnb": "BNB", "microstrategy": "Microstrategy",
    ]

    /// The coin display name for the footer, derived from the event's tags. Falls back to
    /// "Crypto" if no known coin tag is present.
    private static func coinLabel(for event: Event) -> String {
        for tag in event.tags {
            if let label = coinLabels[tag.slug.lowercased()] { return label }
        }
        return "Crypto"
    }

    /// Ticker symbols for `polymarket.com/api/crypto/*` (the real dollar spot-price
    /// feed), matched against `event.tags` the same way `coinLabel` is. This screen
    /// isn't BTC-only, so the symbol sent to that feed must reflect the actual event.
    private static let coinSymbols: [String: String] = [
        "bitcoin": "BTC", "ethereum": "ETH", "solana": "SOL",
        "xrp": "XRP", "dogecoin": "DOGE", "bnb": "BNB",
    ]

    /// The coin ticker symbol for the spot-price feed, derived from the event's tags.
    /// Falls back to "BTC" only as a last resort (shouldn't happen for a
    /// `.upDown`-classified event, which always carries a known coin tag in practice).
    private static func coinSymbol(for event: Event) -> String {
        for tag in event.tags {
            if let symbol = coinSymbols[tag.slug.lowercased()] { return symbol }
        }
        return "BTC"
    }

    /// How long this event's betting window runs, from the cadence its series slug encodes.
    ///
    /// The destination derives the window *open* — and with it the price to beat, the
    /// spot-price range and the chart's title — from `windowEnd` minus this, so a daily
    /// market handed the 5-minute default charts the last five minutes of a 24-hour window.
    /// Falls back to 5 minutes for a series with no recognizable cadence.
    private static func windowInterval(for event: Event) -> TimeInterval {
        RecurrenceCadence(seriesSlug: event.recurrence)?.windowSeconds ?? 300
    }
}
