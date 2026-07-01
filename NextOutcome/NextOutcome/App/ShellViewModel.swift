//
//  ShellViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation
import DesignSystem
import PortfolioPresentation
import PortfolioDomain

/// Derives shell chrome data (live balance label, short address) from the portfolio VM.
@MainActor
@Observable
final class ShellViewModel {
    private let portfolio: PortfolioViewModel

    init(portfolio: PortfolioViewModel) { self.portfolio = portfolio }

    /// Portfolio tab label, e.g. "$7.02".
    var balanceLabel: String {
        switch portfolio.state {
        case .loaded(let p): return ShellFormat.balanceLabel(p.value)
        default:             return ShellFormat.balanceLabel(nil)
        }
    }

    /// Drawer header, e.g. "0xd8C7e8F2…".
    var addressShort: String {
        ShellFormat.shortAddress(portfolio.address)
    }
}
