//
//  OrderTicket.swift
//  NextOutcome
//
//  Created by Sok Pich on 01/07/2026.
//

import Foundation

public enum OrderSide: String, Sendable, Hashable {
    case buy = "BUY"
    case sell = "SELL"
}

/// User intent for an order, before signing. Prices/sizes stay `Decimal`.
public struct OrderTicket: Hashable, Sendable {
    public let tokenID: String
    public let side: OrderSide
    public let price: Decimal   // 0…1
    public let size: Decimal    // shares

    public init(tokenID: String, side: OrderSide, price: Decimal, size: Decimal) {
        self.tokenID = tokenID
        self.side = side
        self.price = price
        self.size = size
    }

    /// Validate against tick size and minimum order size before signing/submitting.
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

public enum OrderValidation: Equatable, Sendable {
    case valid
    case invalid(String)
}
