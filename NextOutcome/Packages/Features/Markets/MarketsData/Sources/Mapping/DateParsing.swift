//
//  DateParsing.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation

enum DateParsing {
    static func parse(_ string: String?) -> Date? {
        guard let string else { return nil }
        return ISO8601DateFormatter().date(from: string)
    }
}
