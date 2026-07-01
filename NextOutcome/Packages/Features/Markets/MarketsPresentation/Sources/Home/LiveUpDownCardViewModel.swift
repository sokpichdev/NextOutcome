import Foundation
import MarketsDomain
import OrderbookPresentation
import OrderbookDomain

/// Derives a live "Up %" for the Home live card from the order-book midpoint,
/// falling back to the Up outcome's static price when the stream has no book yet.
@MainActor
@Observable
public final class LiveUpDownCardViewModel {
    private let upOutcome: Outcome
    private let live: MarketLiveViewModel

    public init(upOutcome: Outcome, factory: MarketLiveViewModelFactory) {
        self.upOutcome = upOutcome
        self.live = factory(upOutcome.id)
    }

    public func start() { live.start() }
    public func stop() { live.stop() }

    /// 0…1 Up probability: live midpoint if available, else the static outcome price.
    public var upFraction: Double {
        let value = live.book?.midpoint ?? upOutcome.price
        return NSDecimalNumber(decimal: value).doubleValue
    }

    public var upPercentText: String { "\(Int((upFraction * 100).rounded()))%" }
}
