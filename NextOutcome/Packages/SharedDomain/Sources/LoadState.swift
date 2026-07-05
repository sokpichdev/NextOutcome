//
//  LoadState.swift
//  NextOutcome
//

/// Generic async-load state for presentation-layer view models. Every C2 view model
/// should route its fetch results through this so failures always have somewhere to go
/// (never silently swallowed into an empty/default value).
///
/// This is generic over `Value`, so any view model can reuse it instead of inventing
/// its own "isLoading" + "error" + "data" boolean/optional soup. A typical SwiftUI
/// view just switches over this enum to decide whether to show a spinner, an empty
/// state, the real content, or an error message.
public enum LoadState<Value: Sendable>: Sendable {
    /// Nothing has happened yet — the view model hasn't started a fetch.
    /// Views typically render nothing (or a placeholder) in this state.
    case idle

    /// A fetch is currently in flight. Views typically show a spinner or skeleton here.
    case loading

    /// The fetch finished successfully and returned data to display.
    /// - Parameter Value: The successfully loaded payload (e.g. an array of markets).
    case loaded(Value)

    /// The fetch finished successfully, but there was no data to show
    /// (e.g. an empty list). Kept separate from `.loaded` so views can show a
    /// dedicated "nothing here" state instead of an empty list.
    case empty

    /// The fetch failed. Carries a human-readable message so the view can display
    /// it directly (e.g. in an error banner or retry prompt).
    /// - Parameter message: A user-facing description of what went wrong.
    case failed(message: String)
}
