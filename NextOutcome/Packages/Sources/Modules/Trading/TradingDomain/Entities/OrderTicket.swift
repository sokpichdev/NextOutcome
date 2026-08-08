//
//  OrderTicket.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

/// Which direction an order goes. Raw values match the strings the CLOB API expects.
public enum OrderSide: String, Sendable, Hashable {
    /// Buying shares of an outcome (betting it will happen).
    case buy = "BUY"
    /// Selling shares you hold of an outcome.
    case sell = "SELL"
}

/// What the user wants to trade, captured *before* the order is cryptographically
/// signed. Prices and sizes are kept as `Decimal` (not `Double`) so money math stays
/// exact and free of floating-point rounding errors.
public struct OrderTicket: Hashable, Sendable {
    /// The CLOB token (outcome) being traded — identifies the specific Yes/No side.
    public let tokenID: String
    /// Whether this is a buy or a sell.
    public let side: OrderSide
    /// Price per share, expressed as a probability between 0 and 1 (e.g. `0.62` = 62¢).
    public let price: Decimal   // 0…1
    /// Number of shares to trade.
    public let size: Decimal    // shares

    /// Creates an order ticket from the user's chosen side, price, and size.
    /// - Parameters:
    ///   - tokenID: The outcome token to trade.
    ///   - side: Buy or sell.
    ///   - price: Price per share in the 0…1 range.
    ///   - size: Number of shares.
    public init(tokenID: String, side: OrderSide, price: Decimal, size: Decimal) {
        self.tokenID = tokenID
        self.side = side
        self.price = price
        self.size = size
    }

    /// Checks the ticket is well-formed before it gets signed and submitted, catching
    /// bad input early so the exchange doesn't reject it.
    ///
    /// Three rules are enforced: the price must be strictly between 0 and 1, the size
    /// must meet the market's minimum, and the price must land exactly on the market's
    /// tick-size grid (e.g. a 0.01 tick means prices like 0.615 are illegal).
    /// - Parameters:
    ///   - tickSize: The smallest price increment the market allows.
    ///   - minOrderSize: The smallest number of shares the market accepts.
    /// - Returns: `.valid`, or `.invalid` with a user-facing reason string.
    public func validate(tickSize: Decimal, minOrderSize: Decimal) -> OrderValidation {
        guard price > 0, price < 1 else { return .invalid("Price must be between 0 and 1.") }
        guard size >= minOrderSize else { return .invalid("Below minimum order size.") }
        // price must be a whole multiple of tickSize
        if tickSize > 0 {
            let ratio = price / tickSize
            let rounded = (ratio as NSDecimalNumber).rounding(accordingToBehavior: nil)
            if Decimal(string: rounded.stringValue) != ratio { return .invalid("Price is off tick size.") }
        }
        return .valid
    }
}

/// The result of validating an `OrderTicket`.
public enum OrderValidation: Equatable, Sendable {
    /// The ticket passed all checks and is safe to sign/submit.
    case valid
    /// The ticket failed a check.
    /// - Parameter String: A user-facing explanation of what's wrong.
    case invalid(String)
}
