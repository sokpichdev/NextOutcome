//
//  JSONDecoder.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation

public extension JSONDecoder {
    static let polymarket: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
}
