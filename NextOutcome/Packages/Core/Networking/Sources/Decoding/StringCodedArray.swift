//
//  StringCodedArray.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation

/// Gamma returns some arrays as a JSON string: "[\"a\",\"b\"]"
/// Wrap the field with this to auto-deode the double-encoded string.
///
/// This is Gamma's API quirk of "stringly-encoded JSON": instead of returning a
/// real JSON array for some fields, it returns a JSON string that itself contains
/// serialized JSON (double-encoding). Without this wrapper, decoding those fields
/// directly as `[T]` would fail. Annotate the property with `@StringCodedArray`
/// and it transparently handles both the double-encoded string form and a normal
/// array, in case a future API response fixes the quirk.
///
/// Usage example:
/// ```swift
/// struct MarketDTO: Decodable {
///     @StringCodedArray var outcomes: [String]
/// }
/// ```
@propertyWrapper
public struct StringCodedArray<T: Codable>: Codable {
    /// The actual decoded array, regardless of whether the source JSON had it as
    /// a double-encoded string or a normal array.
    public var wrappedValue: [T]

    /// Wraps an existing array. Used when constructing a DTO manually (e.g. in
    /// tests or previews) rather than decoding it from JSON.
    /// - Parameter wrappedValue: The array value to wrap.
    public init(wrappedValue: [T]) {
        self.wrappedValue = wrappedValue
    }

    /// Decodes an array from either a double-encoded JSON string or a normal JSON
    /// array.
    ///
    /// Tries to decode as a `String` first, converts that string to UTF-8 `Data`,
    /// and re-decodes it as `[T]` (the double-encoded case Gamma actually sends).
    /// If that fails, falls back to decoding directly as `[T]`.
    /// - Parameter decoder: The decoder supplied by `Codable` machinery.
    /// - Throws: A decoding error if the value is neither a valid encoded string
    ///   nor a plain array of `T`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self),
           let data = string.data(using: .utf8) {
            wrappedValue = try JSONDecoder().decode([T].self, from: data)
        } else {
            wrappedValue = try container.decode([T].self)
        }
    }

    /// Encodes the wrapped array back out as a normal JSON array (not
    /// re-double-encoded as a string).
    /// - Parameter encoder: The encoder supplied by `Codable` machinery.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}
