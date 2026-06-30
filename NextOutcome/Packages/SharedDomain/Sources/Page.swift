//
//  Page.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

public struct Page<T> {
    public let items: [T]
    public let nextCursor: String?
    
    public init(items: [T], nextCursor: String?) {
        self.items = items
        self.nextCursor = nextCursor
    }
}
