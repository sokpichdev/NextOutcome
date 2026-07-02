//
//  LoadState.swift
//  NextOutcome
//

/// Generic async-load state for presentation-layer view models. Every C2 view model
/// should route its fetch results through this so failures always have somewhere to go
/// (never silently swallowed into an empty/default value).
public enum LoadState<Value: Sendable>: Sendable {
    case idle
    case loading
    case loaded(Value)
    case empty
    case failed(message: String)
}
