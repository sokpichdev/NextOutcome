import Foundation
import MarketsDomain
import OrderbookPresentation
import OrderbookDomain

/// Derives a live "Up %" for the Home live card from the order-book midpoint,
/// falling back to the Up outcome's static price when the stream has no book yet.
@MainActor
@Observable
public final class LiveUpDownCardViewModel {
    /// The "Up" outcome, whose static price is the fallback.
    private let upOutcome: Outcome
    /// The underlying live-market view model providing the book midpoint.
    private let live: MarketLiveViewModel

    /// Creates the view model, building the underlying live model for the Up token.
    /// - Parameters:
    ///   - upOutcome: The "Up" outcome to track.
    ///   - factory: Builds the live-market view model for the Up token id.
    public init(upOutcome: Outcome, factory: MarketLiveViewModelFactory) {
        self.upOutcome = upOutcome
        self.live = factory(upOutcome.id)
    }

    /// Starts the underlying live stream.
    public func start() { live.start() }
    /// Stops the underlying live stream.
    public func stop() { live.stop() }

    /// 0…1 Up probability: live midpoint if available, else the static outcome price.
    public var upFraction: Double {
        let value = live.book?.midpoint ?? upOutcome.price
        return NSDecimalNumber(decimal: value).doubleValue
    }

    /// The Up probability formatted as a whole-percent string (e.g. "51%").
    public var upPercentText: String { "\(Int((upFraction * 100).rounded()))%" }
}
