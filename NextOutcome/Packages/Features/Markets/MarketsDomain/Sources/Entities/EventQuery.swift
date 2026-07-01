//
//  EventQuery.swift
//  NextOutcome
//

public enum EventSort: Sendable {
    case volume24h, liquidity, newest, endingSoon, competitive
}

public enum EventStatus: Sendable {
    case active, all
}
