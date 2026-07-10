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

    /// The top 2 markets shown as a preview. The full, untruncated list lives one level
    /// deeper — tapping the card pushes `EventDetailView`, which lists every strike via
    /// `MarketGroupSection` (already built, no changes needed). Matches
    /// `MultiOutcomeCard`'s existing `prefix(3)` precedent for the same "preview, not the
    /// full list" idea.
    private var previewMarkets: [Market] { Array(event.markets.prefix(2)) }

    public var body: some View {
        NavigationLink(value: event) {
            DSCard {
                VStack(alignment: .leading, spacing: DSLayout.spacing) {
                    HStack(spacing: DSLayout.spacing) {
                        CardIcon(url: event.imageURL)
                        Text(event.title).font(DSFont.headline)
                            .foregroundStyle(DSColor.textPrimary).lineLimit(1)
                        Spacer()
                    }
                    ForEach(previewMarkets) { market in
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
                    Label("LIVE · \(Self.coinLabel(for: event))", systemImage: "circle.fill")
                        .font(DSFont.caption).foregroundStyle(DSColor.negative)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// Formats a market's row label. Every `CryptoMarketKind` shows the market's
    /// `groupItemTitle` as-is — including `.hitPrice`, whose real Gamma data already
    /// embeds a per-row direction arrow (e.g. `"↑ 100,000"` or `"↓ 60,000"`), sometimes
    /// mixing both directions within the same event (e.g. a long-dated "what price will
    /// X hit" market with strikes both above and below the current price). Falls back to
    /// the market's `question` when `groupItemTitle` is `nil`.
    /// - Parameters:
    ///   - market: The market whose row is being labeled.
    ///   - kind: The event's classified kind. Currently unused in the body — every kind
    ///     formats identically — but kept in the signature since it's part of the public
    ///     call contract established across Tasks 3/4, and a future kind-specific format
    ///     may need it again.
    ///   - eventTitle: Unused; kept for API stability with existing call sites.
    public static func rowLabel(for market: Market, kind: CryptoMarketKind, eventTitle: String) -> String {
        market.groupItemTitle ?? market.question
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
