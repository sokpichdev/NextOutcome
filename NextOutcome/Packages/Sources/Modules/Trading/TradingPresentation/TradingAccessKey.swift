//
//  TradingAccessKey.swift
//  NextOutcome
//
//  Created by Sok Pich on 12/8/2026.
//

import SwiftUI
import TradingDomain

/// App-provided trading access, resolved from the geoblock endpoint by
/// `TradingAccessViewModel`. Defaults to `.allowed` so previews and tests render the
/// normal trade sheet without wiring anything; `RootView` injects the real value.
///
/// This is an environment value rather than a parameter on purpose: `TradeSheet` is
/// presented from six screens, and gating each call site would be six chances to miss
/// one. Reading it inside the sheet gates every entry point, including ones added later.
private struct TradingAccessKey: EnvironmentKey {
    /// Defaults to allowed so previews/tests aren't gated by accident.
    static let defaultValue: TradingAccess = .allowed
}

public extension EnvironmentValues {
    /// Whether the user may open a position. Read with `@Environment(\.tradingAccess)`.
    var tradingAccess: TradingAccess {
        get { self[TradingAccessKey.self] }
        set { self[TradingAccessKey.self] = newValue }
    }
}
