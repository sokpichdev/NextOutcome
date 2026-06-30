//
//  DecimalString.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation
/// Polymarket prices arrice as decimal strings e.g. "0.62".
/// never parse prices as Double - use this wrapper instead.
@propertyWrapper
public struct DecimalString: Codable {
    public var wrappedValue: Decimal
    
    public init(wrappedValue: Decimal) {
        self.wrappedValue = wrappedValue
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self),
           let decimal = Decimal(string: string) {
            wrappedValue = decimal
        } else {
            let double = try container.decode(Double.self)
            wrappedValue = Decimal(double)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode("\(wrappedValue)")
    }
}
