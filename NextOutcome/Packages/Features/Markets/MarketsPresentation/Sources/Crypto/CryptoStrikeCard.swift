import SwiftUI
import MarketsDomain
import DesignSystem

/// A "multi-strike" Yes/No card: one row per market, each showing a strike/range label,
/// the Yes price, and Yes/No pills. Covers three Crypto sub-tab shapes (Above/Below, Price
/// Range, Hit Price) that only differ in how each row's label is formatted.
public struct CryptoStrikeCard: View {
    /// The event backing the card.
    private let event: Event
    /// The event's classified kind, controlling row-label formatting.
    private let kind: CryptoMarketKind

    /// Creates the card.
    /// - Parameters:
    ///   - event: The event to display.
    ///   - kind: The event's classified `CryptoMarketKind`.
    public init(event: Event, kind: CryptoMarketKind) {
        self.event = event
        self.kind = kind
    }

    public var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                HStack(spacing: DSLayout.spacing) {
                    CardIcon(url: event.imageURL)
                    Text(event.title).font(DSFont.headline)
                        .foregroundStyle(DSColor.textPrimary).lineLimit(1)
                    Spacer()
                }
                ForEach(event.markets) { market in
                    NavigationLink(value: MarketNavigationTarget(market: market, eventID: event.id)) {
                        HStack {
                            Text(Self.rowLabel(for: market, kind: kind, eventTitle: event.title))
                                .font(DSFont.subheadline)
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
                Label("LIVE · \(Self.coinLabel(for: event))", systemImage: "circle.fill")
                    .font(DSFont.caption).foregroundStyle(DSColor.negative)
            }
        }
    }

    /// Formats a market's row label per its `CryptoMarketKind`. `.aboveBelow`/`.priceRange`
    /// show the market's `groupItemTitle` as-is; `.hitPrice` prefixes it with a direction
    /// arrow — `↑` if the event title suggests an upward target, `↓` if it suggests
    /// downward ("or lower"/"dip to"/"below"), defaulting to `↑` when neither phrase is
    /// present (best-effort; see the design spec's "Risks / notes"). Falls back to the
    /// market's `question` when `groupItemTitle` is `nil`.
    /// - Parameters:
    ///   - market: The market whose row is being labeled.
    ///   - kind: The event's classified kind.
    ///   - eventTitle: The event's title, used only for `.hitPrice`'s direction heuristic.
    public static func rowLabel(for market: Market, kind: CryptoMarketKind, eventTitle: String) -> String {
        let raw = market.groupItemTitle ?? market.question
        guard kind == .hitPrice else { return raw }
        let lower = eventTitle.lowercased()
        let isDown = lower.contains("or lower") || lower.contains("dip to") || lower.contains("below")
        return (isDown ? "↓ " : "↑ ") + raw
    }

    /// Known coin tag slugs, mapped to their display label, matched against `event.tags`.
    private static let coinLabels: [String: String] = [
        "bitcoin": "Bitcoin", "ethereum": "Ethereum", "solana": "Solana",
        "xrp": "XRP", "dogecoin": "Dogecoin", "bnb": "BNB", "microstrategy": "Microstrategy",
    ]

    /// The coin display name for an event's footer, derived from its tags. Falls back to
    /// "Crypto" if no known coin tag is present.
    private static func coinLabel(for event: Event) -> String {
        for tag in event.tags {
            if let label = coinLabels[tag.slug.lowercased()] { return label }
        }
        return "Crypto"
    }
}
