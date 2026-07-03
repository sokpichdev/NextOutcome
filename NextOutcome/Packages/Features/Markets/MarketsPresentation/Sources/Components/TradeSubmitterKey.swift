//
//  TradeSubmitterKey.swift
//  NextOutcome
//

import SwiftUI
import TradingDomain

/// App-provided `TradeSubmitting` for the mock trade sheet. Defaults to
/// `SimulatedTradeSubmitter` so previews/tests work without the app wiring anything;
/// `AppContainer`/`RootView` inject the same simulated submitter today. Task D swaps
/// this environment value for a real submitter with zero UI changes.
private struct TradeSubmitterKey: EnvironmentKey {
    static let defaultValue: TradeSubmitting = SimulatedTradeSubmitter()
}

public extension EnvironmentValues {
    var tradeSubmitter: TradeSubmitting {
        get { self[TradeSubmitterKey.self] }
        set { self[TradeSubmitterKey.self] = newValue }
    }
}
