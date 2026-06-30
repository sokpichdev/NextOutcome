//
//  Endpoint.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation

public struct Endpoint {
    public let host: PolymarketService
    public let path: String
    public let method: HTTPMethod
    public let query: [String: String]
    public let body: Data?
    
    public init(
        host: PolymarketService,
        path: String,
        method: HTTPMethod = .get,
        query: [String: String] = [:],
        body: Data? = nil
    ) {
        self.host = host
        self.path = path
        self.method = method
        self.query = query
        self.body = body
    }
    
    public var urlRequest: URLRequest? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host.baseURL
        components.path = path
        if !query.isEmpty {
            components.queryItems = query.map {
                URLQueryItem(name: $0.key, value: $0.value)
            }
        }
        guard let url = components.url else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }
}
