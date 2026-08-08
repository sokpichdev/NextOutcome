//
//  WatchAddressStore.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// Shared persistence for the watched wallet address so the Portfolio and Activity
/// tabs stay in sync. Backed by `UserDefaults`.
public struct WatchAddressStore {
    /// The `UserDefaults` instance to persist into (injectable for tests).
    private let defaults: UserDefaults
    /// The defaults key under which the address is stored.
    private static let key = "portfolio.watchAddress"

    /// Creates the store.
    /// - Parameter defaults: The `UserDefaults` to use. Defaults to `.standard`.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The currently-watched address, or `nil` if none is saved.
    public var address: String? {
        defaults.string(forKey: Self.key)
    }

    /// Persists a watched address.
    /// - Parameter address: The address to save.
    public func save(_ address: String) {
        defaults.set(address, forKey: Self.key)
    }

    /// Removes any saved watched address.
    public func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
