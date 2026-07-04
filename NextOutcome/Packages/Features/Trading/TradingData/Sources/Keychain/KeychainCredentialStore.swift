//
//  KeychainCredentialStore.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import Security
import TradingDomain

/// Stores the app↔proxy session token in the Keychain, device-only, unlocked-access.
/// Never stores L2 secrets (those live server-side) and never logs the value.
public struct KeychainCredentialStore: CredentialStore {
    /// The Keychain "service" namespace all entries are stored under. Configurable so
    /// tests can use an isolated namespace.
    private let service: String
    /// The fixed account key identifying the single session-token entry.
    private let account = "proxy.session.token"

    /// Creates the store.
    /// - Parameter service: The Keychain service namespace. Defaults to the app's bundle-like id.
    public init(service: String = "com.nextoutcome.trading") {
        self.service = service
    }

    /// Saves (or overwrites) the session token in the Keychain.
    ///
    /// Any existing entry is deleted first so this behaves as an upsert. The token is
    /// marked `WhenUnlockedThisDeviceOnly` so it's never backed up or synced off-device.
    /// - Parameter sessionToken: The token to persist.
    /// - Throws: `KeychainError.status` if the Keychain write fails.
    public func save(sessionToken: String) throws {
        let data = Data(sessionToken.utf8)
        var query = baseQuery()
        SecItemDelete(query as CFDictionary)   // overwrite semantics
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
    }

    /// Reads the stored session token.
    /// - Returns: The token, or `nil` if none is stored yet.
    /// - Throws: `KeychainError.status` if the read fails for any reason other than "not found".
    public func loadSessionToken() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw KeychainError.status(status) }
        return String(decoding: data, as: UTF8.self)
    }

    /// Deletes the stored session token (e.g. on logout). Succeeds even if nothing was stored.
    /// - Throws: `KeychainError.status` if deletion fails unexpectedly.
    public func clear() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.status(status) }
    }

    /// Builds the common Keychain query dictionary (class + service + account) shared by
    /// every operation, so the same entry is targeted consistently.
    /// - Returns: A base query identifying this store's single token entry.
    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

/// Wraps a raw Keychain failure code so callers get a typed Swift error.
public enum KeychainError: Error, Equatable {
    /// A Keychain API call returned a non-success status.
    /// - Parameter OSStatus: The raw `OSStatus` code from the Security framework.
    case status(OSStatus)
}
