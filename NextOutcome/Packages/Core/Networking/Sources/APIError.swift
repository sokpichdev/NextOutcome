//
//  APIError.swift
//  NextOutcome
//
//  Created by Sok Pich on 30/06/2026.
//

import Foundation

public enum APIError: Error {
    case badURL
    case http(statusCode: Int, body: Data)
    case decoding(Error)
    case rateLimited
    case unknown(Error)
}
