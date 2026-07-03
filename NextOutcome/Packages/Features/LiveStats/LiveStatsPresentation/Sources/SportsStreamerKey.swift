//
//  SportsStreamerKey.swift
//  NextOutcome
//
//  Created by Sok Pich on 03/07/2026.
//

import SwiftUI
import LiveStatsDomain

/// App-provided sports live-stats streamer. Injected by `AppContainer` so the Live sub-tab
/// stays free of any Data-layer dependency. `nil` in previews/tests renders the
/// "Not available" placeholder.
private struct SportsStreamerKey: EnvironmentKey {
    static let defaultValue: (any SportsStateStreaming)? = nil
}

public extension EnvironmentValues {
    var sportsStreamer: (any SportsStateStreaming)? {
        get { self[SportsStreamerKey.self] }
        set { self[SportsStreamerKey.self] = newValue }
    }
}
