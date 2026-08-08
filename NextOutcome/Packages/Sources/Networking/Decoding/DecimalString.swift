//
//  DecimalString.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation
/// Polymarket prices arrice as decimal strings e.g. "0.62".
/// never parse prices as Double - use this wrapper instead.
///
/// Why this exists: `Double` cannot represent decimal values like `0.1` exactly in
/// binary floating point, which causes tiny rounding errors that are unacceptable
/// for money/price calculations (payouts, prices, order sizes). `Decimal` avoids
/// this, but Polymarket's JSON API sometimes sends prices as strings (`"0.62"`)
/// and sometimes as raw numbers. This property wrapper hides that inconsistency:
/// annotate any `Decimal` field on a DTO with `@DecimalString` and it will decode
/// correctly either way.
///
/// Usage example:
/// ```swift
/// struct MarketDTO: Decodable {
///     @DecimalString var price: Decimal
/// }
/// ```
@propertyWrapper
public struct DecimalString: Codable {
    /// The actual decoded price/value, always as a `Decimal` regardless of whether
    /// the source JSON had it as a string or a number.
    public var wrappedValue: Decimal

    /// Wraps an existing `Decimal` value. Used when constructing a DTO manually
    /// (e.g. in tests or previews) rather than decoding it from JSON.
    /// - Parameter wrappedValue: The decimal value to wrap.
    public init(wrappedValue: Decimal) {
        self.wrappedValue = wrappedValue
    }

    /// Decodes a `Decimal` from either a JSON string (`"0.62"`) or a JSON number
    /// (`0.62`).
    ///
    /// Tries to decode as a `String` first and parse that into a `Decimal` (the
    /// common case for Polymarket responses); if that fails, falls back to
    /// decoding as a `Double` and converting it to `Decimal`.
    /// - Parameter decoder: The decoder supplied by `Codable` machinery.
    /// - Throws: A decoding error if the value is neither a valid decimal string
    ///   nor a number.
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

    /// Encodes the wrapped `Decimal` back out as a string, matching the format
    /// Polymarket's API expects when sending values back (e.g. in order requests).
    /// - Parameter encoder: The encoder supplied by `Codable` machinery.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode("\(wrappedValue)")
    }
}
