//
//  JSONDecoder.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation

public extension JSONDecoder {
    /// The shared `JSONDecoder` configured for Polymarket's API responses, used by
    /// `APIClient` by default for every request.
    ///
    /// Polymarket's JSON keys use `snake_case` (e.g. `"end_date"`), while Swift
    /// model properties use `camelCase` (e.g. `endDate`). Setting
    /// `keyDecodingStrategy = .convertFromSnakeCase` means DTOs don't need to
    /// manually spell out `CodingKeys` for every property just to rename them.
    static let polymarket: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
}
