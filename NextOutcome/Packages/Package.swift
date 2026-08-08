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
        // Trading — isolated, quarantined. The read-only app never links these.
        .library(name: "TradingDomain",          targets: ["TradingDomain"]),
        .library(name: "TradingData",            targets: ["TradingData"]),
        .library(name: "LiveStatsDomain",        targets: ["LiveStatsDomain"]),
        .library(name: "LiveStatsData",          targets: ["LiveStatsData"]),
        .library(name: "LiveStatsPresentation",  targets: ["LiveStatsPresentation"]),
    ],
    targets: [
        // Core — these three sit at Sources/<TargetName>, so SPM finds them without
        // a `path:`. The feature slices below are grouped under Sources/Modules/, which
        // SPM does not auto-discover; each therefore names its own path.
        .target(name: "DesignSystem"),
        .target(name: "Networking"),
        .target(name: "SharedDomain"),

        // Markets feature (vertical slice)
        .target(
            name: "MarketsDomain",
            dependencies: ["SharedDomain"],
            path: "Sources/Modules/Market/MarketsDomain"
        ),
        .target(
            name: "MarketsData",
            dependencies: ["MarketsDomain", "Networking"],
            path: "Sources/Modules/Market/MarketsData"
        ),
        .target(
            name: "MarketsPresentation",
            // TradingDomain (mock trade sheet + simulated submitter only) is the one
            // Trading target the read-only app links; TradingData's real wallet-signing
            // and proxy gateway stay quarantined until Task D.
            dependencies: ["MarketsDomain", "DesignSystem", "OrderbookPresentation", "OrderbookDomain", "SharedDomain", "TradingDomain", "LiveStatsPresentation", "LiveStatsDomain"],
            path: "Sources/Modules/Market/MarketsPresentation"
        ),

        // Orderbook feature (vertical slice + realtime)
        .target(
            name: "OrderbookDomain",
            dependencies: [],
            path: "Sources/Modules/Orderbook/OrderbookDomain"
        ),
        .target(
            name: "OrderbookData",
            dependencies: ["OrderbookDomain", "Networking"],
            path: "Sources/Modules/Orderbook/OrderbookData"
        ),
        .target(
            name: "OrderbookPresentation",
            dependencies: ["OrderbookDomain", "DesignSystem", "SharedDomain"],
            path: "Sources/Modules/Orderbook/OrderbookPresentation"
        ),

        // Portfolio feature (watch-only)
        .target(
            name: "PortfolioDomain",
            dependencies: ["SharedDomain"],
            path: "Sources/Modules/Portfolio/PortfolioDomain"
        ),
        .target(
            name: "PortfolioData",
            dependencies: ["PortfolioDomain", "Networking", "SharedDomain"],
            path: "Sources/Modules/Portfolio/PortfolioData"
        ),
        .target(
            name: "PortfolioPresentation",
            dependencies: ["PortfolioDomain", "DesignSystem", "SharedDomain"],
            path: "Sources/Modules/Portfolio/PortfolioPresentation"
        ),

        // Trading feature (isolated; quarantined from the read-only app)
        .target(
            name: "TradingDomain",
            dependencies: [],
            path: "Sources/Modules/Trading/TradingDomain"
        ),
        .target(
            name: "TradingData",
            dependencies: ["TradingDomain", "Networking"],
            path: "Sources/Modules/Trading/TradingData"
        ),

        // LiveStats feature (sports live stats; undocumented feed, isolated slice)
        .target(
            name: "LiveStatsDomain",
            dependencies: [],
            path: "Sources/Modules/LiveStats/LiveStatsDomain"
        ),
        .target(
            name: "LiveStatsData",
            dependencies: ["LiveStatsDomain", "Networking"],
            path: "Sources/Modules/LiveStats/LiveStatsData"
        ),
        .target(
            name: "LiveStatsPresentation",
            dependencies: ["LiveStatsDomain", "DesignSystem", "SharedDomain"],
            path: "Sources/Modules/LiveStats/LiveStatsPresentation"
        ),

        // Tests
        .testTarget(name: "DesignSystemTests",    dependencies: ["DesignSystem"]),
        .testTarget(name: "NetworkingTests",      dependencies: ["Networking"]),
        .testTarget(name: "MarketsDomainTests",   dependencies: ["MarketsDomain"]),
        .testTarget(
            name: "MarketsDataTests",
            dependencies: ["MarketsData", "MarketsDomain", "Networking"]
        ),
        .testTarget(
            name: "MarketsPresentationTests",
            dependencies: ["MarketsPresentation", "OrderbookDomain", "OrderbookPresentation", "SharedDomain", "LiveStatsDomain"]
        ),
        .testTarget(name: "OrderbookDomainTests", dependencies: ["OrderbookDomain"]),
        .testTarget(
            name: "OrderbookDataTests",
            dependencies: ["OrderbookData", "OrderbookDomain", "Networking"]
        ),
        .testTarget(
            name: "OrderbookPresentationTests",
            dependencies: ["OrderbookPresentation", "OrderbookDomain", "DesignSystem", "SharedDomain"]
        ),
        .testTarget(name: "PortfolioDomainTests", dependencies: ["PortfolioDomain"]),
        .testTarget(
            name: "PortfolioDataTests",
            dependencies: ["PortfolioData", "PortfolioDomain", "Networking"]
        ),
        .testTarget(
            name: "PortfolioPresentationTests",
            dependencies: ["PortfolioPresentation", "PortfolioDomain", "SharedDomain"]
        ),
        .testTarget(name: "TradingDomainTests",   dependencies: ["TradingDomain"]),
        .testTarget(
            name: "TradingDataTests",
            dependencies: ["TradingData", "TradingDomain", "Networking"]
        ),
        .testTarget(name: "LiveStatsDomainTests", dependencies: ["LiveStatsDomain"]),
        .testTarget(
            name: "LiveStatsDataTests",
            dependencies: ["LiveStatsData", "LiveStatsDomain", "Networking"]
        ),
        .testTarget(
            name: "LiveStatsPresentationTests",
            dependencies: ["LiveStatsPresentation", "LiveStatsDomain", "DesignSystem", "SharedDomain"]
        ),
    ]
)
