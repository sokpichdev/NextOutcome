//
//  PortfolioRepository.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// Watch-only reads from the Data API. No signing, no custody.
public protocol PortfolioRepository: Sendable {
    func positions(address: String) async throws -> [Position]
    func value(address: String) async throws -> Decimal
}
