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
    private let defaults: UserDefaults
    private static let key = "portfolio.watchAddress"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var address: String? {
        defaults.string(forKey: Self.key)
    }

    public func save(_ address: String) {
        defaults.set(address, forKey: Self.key)
    }

    public func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
