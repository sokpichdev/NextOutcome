//
//  RetryPolicy.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation

public struct RetryPolicy {
    public let maxAttempts: Int
    public let baseDelay: TimeInterval
    
    public static let `default` = RetryPolicy(maxAttempts: 3, baseDelay: 0.5)
    public static let none = RetryPolicy(maxAttempts: 1, baseDelay: 0)
    public func delay(for attemp: Int) -> TimeInterval {
        baseDelay * pow(2.0, Double(attemp))
    }
}
