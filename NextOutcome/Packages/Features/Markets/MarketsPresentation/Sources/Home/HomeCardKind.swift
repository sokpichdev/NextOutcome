import Foundation
import MarketsDomain

/// Which Home card variant an event should render as.
public enum HomeCardKind: Equatable {
    case liveUpDown, news, multiOutcome, hero, standard

    private static let cryptoTags: Set<String> = ["crypto", "bitcoin", "btc", "ethereum"]
    private static let newsTags: Set<String> = ["breaking", "news"]
    private static let sportsTags: Set<String> = ["sports", "soccer", "football"]

    private static func tagSlugs(_ event: Event) -> Set<String> {
        Set(event.tags.flatMap { [$0.slug.lowercased(), $0.label.lowercased()] })
    }

    private static func isUpDown(_ market: Market) -> Bool {
        let titles = Set(market.outcomes.map { $0.title.lowercased() })
        return titles.contains("up") && titles.contains("down")
    }

    private static func isBinaryYesNo(_ market: Market) -> Bool {
        let titles = Set(market.outcomes.map { $0.title.lowercased() })
        return titles.contains("yes") && titles.contains("no")
    }

    /// Natural kind for an event. Never returns `.hero` (hero is a feed-level slot).
    public static func classify(_ event: Event) -> HomeCardKind {
        let slugs = tagSlugs(event)
        if let first = event.markets.first, isUpDown(first), !slugs.isDisjoint(with: cryptoTags) {
            return .liveUpDown
        }
        if event.markets.count == 1, event.imageURL != nil,
           isBinaryYesNo(event.markets[0]), !slugs.isDisjoint(with: newsTags) {
            return .news
        }
        if event.markets.count >= 2 { return .multiOutcome }
        return .standard
    }

    /// True when the event belongs to a sports/soccer category (used to pick the hero slot).
    public static func isSports(_ event: Event) -> Bool {
        !tagSlugs(event).isDisjoint(with: sportsTags)
    }
}
