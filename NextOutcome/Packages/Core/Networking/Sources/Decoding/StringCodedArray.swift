//
//  StringCodedArray.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation

/// Gamma returns some arrays as a JSON string: "[\"a\",\"b\"]"
/// Wrap the field with this to auto-deode the double-encoded string.
@propertyWrapper
public struct StringCodedArray<T: Codable>: Codable {
    public var wrappedValue: [T]
    
    public init(wrappedValue: [T]) {
        self.wrappedValue = wrappedValue
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self),
           let data = string.data(using: .utf8) {
            wrappedValue = try JSONDecoder().decode([T].self, from: data)
        } else {
            wrappedValue = try container.decode([T].self)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}
