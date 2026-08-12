//
//  TradingAccessViewModel.swift
//  NextOutcome
//
//  Created by Sok Pich on 12/8/2026.
//

import Foundation
import Observation
import TradingDomain

/// Resolves whether the user may open a position, and holds the answer for the session.
///
/// The gate this drives is a **UX pre-gate**, not the authority: per
/// `docs/phase-4-wallet-proxy-design.md` §2 the proxy re-checks geoblocking server-side
/// before forwarding any write. That's what makes the failure policy below safe.
///
/// **Fail open, then stick.** `access` starts `.allowed` and only ever changes on a
/// *successful* fetch, so:
/// - a fetch that never succeeded leaves trading open rather than bricking the sheet for
///   everyone on a flaky connection, and
/// - a status that did resolve to a denial survives later network failures, so a blip
///   can't silently unblock someone who was blocked.
///
/// When Phase 5 turns on real writes, `refresh()`'s `catch` is the one place to change to
/// fail closed.
@MainActor
@Observable
public final class TradingAccessViewModel {
    /// What the user is currently allowed to do. Read by `TradeSheet` via the
    /// `\.tradingAccess` environment value.
    public private(set) var access: TradingAccess = .allowed

    /// The geoblock endpoint, or `nil` when a DEBUG launch argument is standing in for it.
    private let service: GeoblockService?
    /// Forces `.allowed` regardless of the fetched status. DEBUG builds only.
    private let override: Bool
    /// A status supplied by launch argument instead of the network. DEBUG builds only.
    private let simulated: GeoblockStatus?

    /// Creates the view model.
    /// - Parameters:
    ///   - service: The geoblock service to query.
    ///   - override: Forces `.allowed`. Callers in release builds must pass `false`.
    ///   - simulated: Stands in for the network response. Release builds must pass `nil`.
    public init(service: GeoblockService?, override: Bool = false, simulated: GeoblockStatus? = nil) {
        self.service = service
        self.override = override
        self.simulated = simulated
    }

    /// Fetches the geoblock status and updates `access`.
    ///
    /// Never throws: a failure deliberately leaves the previous answer in place (see the
    /// type's note on the failure policy).
    public func refresh() async {
        if let simulated {
            access = TradingAccessPolicy.resolve(status: simulated, override: override)
            return
        }
        guard let service else { return }
        do {
            let status = try await service.status()
            access = TradingAccessPolicy.resolve(status: status, override: override)
        } catch {
            // Deliberately keeps the last known answer. Sticky once denied, open if we
            // never got one.
        }
    }
}

#if DEBUG
public extension TradingAccessViewModel {
    /// Builds the view model, honouring the DEBUG-only launch arguments that make the
    /// gate demoable and verifiable in the simulator:
    ///
    /// - `-allowTradingInBlockedRegion` — force `.allowed` even when geoblocked.
    /// - `-simulateGeoblock <blocked|closeOnly|allowed>` — stand in for the endpoint, so
    ///   the denied states can be seen without a VPN.
    ///
    /// Mirrors the `-preselectCategory` pattern in `RootView`. Release builds get
    /// `init(service:)` with both escape hatches off.
    /// - Parameter service: The real geoblock service, used unless `-simulateGeoblock` is set.
    static func launchArgumentDriven(service: GeoblockService) -> TradingAccessViewModel {
        let args = ProcessInfo.processInfo.arguments
        var simulated: GeoblockStatus?
        if let index = args.firstIndex(of: "-simulateGeoblock"), args.count > index + 1 {
            switch args[index + 1] {
            case "blocked":   simulated = GeoblockStatus(blocked: true, closeOnly: false, region: "US")
            case "closeOnly": simulated = GeoblockStatus(blocked: false, closeOnly: true, region: "US")
            case "allowed":   simulated = GeoblockStatus(blocked: false, closeOnly: false, region: nil)
            default:          simulated = nil
            }
        }
        return TradingAccessViewModel(
            service: service,
            override: args.contains("-allowTradingInBlockedRegion"),
            simulated: simulated
        )
    }
}
#endif
