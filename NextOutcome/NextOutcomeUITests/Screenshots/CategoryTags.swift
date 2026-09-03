//
//  CategoryTags.swift
//  NextOutcomeUITests
//
//  Polymarket tag IDs used by `-preselectCategory` in screenshot runs.
//  Verified directly against the live Gamma tags endpoint
//  (`gamma-api.polymarket.com/tags/slug/<slug>`), one request per slug, rather than
//  the bulk `/tags` listing.
//

enum PoliticsTag { static let id = "2" }
enum SportsTag { static let id = "1" }
enum CryptoTag { static let id = "21" }
enum EsportsTag { static let id = "64" }
enum WorldCupTag { static let id = "519" }
