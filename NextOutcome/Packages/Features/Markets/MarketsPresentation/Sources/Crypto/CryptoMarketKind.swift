import Foundation
import MarketsDomain

/// Which Crypto hub sub-tab an event belongs to, classified from its title and market shape.
///
/// There is no dedicated Gamma field distinguishing these shapes — classification is
/// best-effort text/shape matching against the event's title and each market's
/// `groupItemTitle`. See `docs/superpowers/specs/2026-07-10-crypto-hub-design.md` for the
/// full rationale and the "Risks / notes" section on heuristic accuracy.
public enum CryptoMarketKind: Equatable {
    /// A live Up/Down market (e.g. "BTC Up or Down 5m").
    case upDown
    /// A single-strike above/below market (e.g. "Bitcoin above 52,000 on July 10?").
    case aboveBelow
    /// A bucketed price-range market (e.g. "Bitcoin price on July 10?" with "64,000-66,000" rows).
    case priceRange
    /// A "what price will X hit" market.
    case hitPrice
    /// Doesn't match any known crypto shape.
    case other

    /// Classifies an event into a `CryptoMarketKind`. Checks run in this order — the first
    /// match wins — because a `priceRange`-shaped `groupItemTitle` is unambiguous evidence
    /// even if the title also happens to contain "above"/"below".
    public static func classify(_ event: Event) -> CryptoMarketKind {
        if let first = event.markets.first, HomeCardKind.isUpDown(first) {
            return .upDown
        }
        if event.markets.contains(where: { isRangeGroupItemTitle($0.groupItemTitle) }) {
            return .priceRange
        }
        let titleLower = event.title.lowercased()
        if !event.markets.isEmpty,
           titleLower.contains("above") || titleLower.contains("below"),
           event.markets.allSatisfy({ isBareNumberGroupItemTitle($0.groupItemTitle) }) {
            return .aboveBelow
        }
        if titleLower.hasPrefix("what price will") {
            return .hitPrice
        }
        return .other
    }

    /// True when `groupItemTitle` looks like a bucketed range, e.g. `"64,000-66,000"`.
    private static func isRangeGroupItemTitle(_ groupItemTitle: String?) -> Bool {
        guard let groupItemTitle else { return false }
        return groupItemTitle.contains("-") && groupItemTitle.rangeOfCharacter(from: .decimalDigits) != nil
    }

    /// True when `groupItemTitle` is a bare number (no range dash), e.g. `"52,000"`.
    private static func isBareNumberGroupItemTitle(_ groupItemTitle: String?) -> Bool {
        guard let groupItemTitle, !groupItemTitle.isEmpty else { return false }
        return !groupItemTitle.contains("-") && groupItemTitle.rangeOfCharacter(from: .decimalDigits) != nil
    }
}
