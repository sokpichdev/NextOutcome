//
//  StateView.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import SwiftUI

/// A simplified, UI-only version of loading state — used specifically to decide
/// what placeholder view to show (spinner, empty message, or error message).
/// Distinct from `LoadState` (in `SharedDomain`) since this doesn't carry the
/// loaded value itself; it's purely for driving `StateView`'s appearance.
public enum ViewState {
    /// Show a loading spinner.
    case loading
    /// Show a "no results" placeholder.
    case empty
    /// Show an error placeholder with the given message.
    /// - Parameter String: The error message to display to the user.
    case error(String)
}

/// A generic placeholder view for loading, empty, and error states, so every
/// screen doesn't need to hand-roll its own spinner/empty-state UI.
public struct StateView: View {
    /// Which placeholder to render.
    let state: ViewState

    /// Creates a state placeholder view.
    /// - Parameter state: Which state to display.
    public init(_ state: ViewState) { self.state = state }

    public var body: some View {
        switch state {
        case .loading:
             ProgressView()
                .tint(DSColor.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            ContentUnavailableView("No results", systemImage: "tray")
        case .error(let msg):
            ContentUnavailableView(msg, systemImage: "exclamationmark.triangle")
        }
    }
}
