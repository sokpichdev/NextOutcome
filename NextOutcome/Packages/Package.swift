// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NextOutcome",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DesignSystem",        targets: ["DesignSystem"]),
        .library(name: "Networking",           targets: ["Networking"]),
        .library(name: "SharedDomain",         targets: ["SharedDomain"]),
        .library(name: "MarketsDomain",        targets: ["MarketsDomain"]),
        .library(name: "MarketsData",          targets: ["MarketsData"]),
        .library(name: "MarketsPresentation",  targets: ["MarketsPresentation"]),
        .library(name: "OrderbookDomain",        targets: ["OrderbookDomain"]),
        .library(name: "OrderbookData",          targets: ["OrderbookData"]),
        .library(name: "OrderbookPresentation",  targets: ["OrderbookPresentation"]),
        .library(name: "PortfolioDomain",        targets: ["PortfolioDomain"]),
        .library(name: "PortfolioData",          targets: ["PortfolioData"]),
        .library(name: "PortfolioPresentation",  targets: ["PortfolioPresentation"]),
    ],
    targets: [
        // Core
        .target(name: "DesignSystem", path: "Core/DesignSystem/Sources"),
        .target(name: "Networking",   path: "Core/Networking/Sources"),
        .target(name: "SharedDomain", path: "SharedDomain/Sources"),

        // Markets feature (vertical slice)
        .target(
            name: "MarketsDomain",
            dependencies: ["SharedDomain"],
            path: "Features/Markets/MarketsDomain/Sources"
        ),
        .target(
            name: "MarketsData",
            dependencies: ["MarketsDomain", "Networking"],
            path: "Features/Markets/MarketsData/Sources"
        ),
        .target(
            name: "MarketsPresentation",
            dependencies: ["MarketsDomain", "DesignSystem", "OrderbookPresentation"],
            path: "Features/Markets/MarketsPresentation/Sources"
        ),

        // Orderbook feature (vertical slice + realtime)
        .target(
            name: "OrderbookDomain",
            dependencies: [],
            path: "Features/Orderbook/OrderbookDomain/Sources"
        ),
        .target(
            name: "OrderbookData",
            dependencies: ["OrderbookDomain", "Networking"],
            path: "Features/Orderbook/OrderbookData/Sources"
        ),
        .target(
            name: "OrderbookPresentation",
            dependencies: ["OrderbookDomain", "DesignSystem"],
            path: "Features/Orderbook/OrderbookPresentation/Sources"
        ),

        // Portfolio feature (watch-only)
        .target(
            name: "PortfolioDomain",
            dependencies: ["SharedDomain"],
            path: "Features/Portfolio/PortfolioDomain/Sources"
        ),
        .target(
            name: "PortfolioData",
            dependencies: ["PortfolioDomain", "Networking", "SharedDomain"],
            path: "Features/Portfolio/PortfolioData/Sources"
        ),
        .target(
            name: "PortfolioPresentation",
            dependencies: ["PortfolioDomain", "DesignSystem", "SharedDomain"],
            path: "Features/Portfolio/PortfolioPresentation/Sources"
        ),

        // Tests
        .testTarget(name: "NetworkingTests",     dependencies: ["Networking"]),
        .testTarget(name: "MarketsDomainTests",  dependencies: ["MarketsDomain"]),
        .testTarget(
            name: "MarketsDataTests",
            dependencies: ["MarketsData", "MarketsDomain", "Networking"]
        ),
        .testTarget(name: "OrderbookDomainTests", dependencies: ["OrderbookDomain"]),
        .testTarget(
            name: "OrderbookDataTests",
            dependencies: ["OrderbookData", "OrderbookDomain", "Networking"]
        ),
        .testTarget(name: "PortfolioDomainTests", dependencies: ["PortfolioDomain"]),
        .testTarget(
            name: "PortfolioDataTests",
            dependencies: ["PortfolioData", "PortfolioDomain", "Networking"]
        ),
    ]
)
