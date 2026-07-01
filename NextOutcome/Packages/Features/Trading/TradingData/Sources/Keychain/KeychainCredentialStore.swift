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
    private let service: String
    private let account = "proxy.session.token"

    public init(service: String = "com.nextoutcome.trading") {
        self.service = service
    }

    public func save(sessionToken: String) throws {
        let data = Data(sessionToken.utf8)
        var query = baseQuery()
        SecItemDelete(query as CFDictionary)   // overwrite semantics
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.status(status) }
    }

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

    public func clear() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.status(status) }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

public enum KeychainError: Error, Equatable {
    case status(OSStatus)
}
