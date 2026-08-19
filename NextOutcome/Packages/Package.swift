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
        // Trading — isolated. The app links Domain/Data/Presentation for the mock trade
        // sheet and the geoblock gate; what stays quarantined is wallet *signing*, which
        // is an `UnavailableWalletSigner` stub until a vetted secp256k1/EIP-712
        // implementation passes security review.
        .library(name: "TradingDomain",          targets: ["TradingDomain"]),
        .library(name: "TradingData",            targets: ["TradingData"]),
        .library(name: "TradingPresentation",    targets: ["TradingPresentation"]),
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
            // TradingDomain supplies the mock trade sheet's simulated submitter;
            // TradingPresentation supplies the geoblock gate the sheet renders when the
            // user's region can't open a position. Neither pulls in TradingData — the
            // App composition root injects that.
            dependencies: ["MarketsDomain", "DesignSystem", "OrderbookPresentation", "OrderbookDomain", "SharedDomain", "TradingDomain", "TradingPresentation", "LiveStatsPresentation", "LiveStatsDomain"],
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

        // Trading feature (isolated; wallet signing stays stubbed pending security review)
        .target(
            name: "TradingDomain",
            // SharedDomain carries `PayoutCalculator`, which the crypto live screen quotes
            // too — see its doc comment for why the math lives in the shared kernel.
            dependencies: ["SharedDomain"],
            path: "Sources/Modules/Trading/TradingDomain"
        ),
        .target(
            name: "TradingData",
            dependencies: ["TradingDomain", "Networking"],
            path: "Sources/Modules/Trading/TradingData"
        ),
        .target(
            name: "TradingPresentation",
            dependencies: ["TradingDomain", "DesignSystem"],
            path: "Sources/Modules/Trading/TradingPresentation"
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
        .testTarget(name: "SharedDomainTests",    dependencies: ["SharedDomain"]),
        .testTarget(name: "TradingDomainTests",   dependencies: ["TradingDomain", "SharedDomain"]),
        .testTarget(
            name: "TradingDataTests",
            dependencies: ["TradingData", "TradingDomain", "Networking"]
        ),
        .testTarget(
            name: "TradingPresentationTests",
            dependencies: ["TradingPresentation", "TradingDomain"]
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
