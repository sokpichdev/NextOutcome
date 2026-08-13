//
//  CryptoHubView.swift
//  NextOutcome
//
//  Created by Sok Pich on 10/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem
import OrderbookPresentation

/// The Crypto hub: sort/period menus, sub-tabs (All/Up-Down/Above-Below/Price Range/Hit
/// Price), and the matching card per event. Reached by tapping the Crypto chip in the home
/// category rail, replacing the generic `EventListView` for that category.
public struct CryptoHubView: View {
    /// The view model driving the hub.
    @State private var viewModel: CryptoHubViewModel
    /// The Crypto tag's live Gamma id, resolved by `HubTabsViewModel` before this view can
    /// ever be selected. `nil` only as a defensive type-level guard — see the design spec's
    /// "Wiring" section for why this can't happen in practice.
    private let tagID: String?

    /// Creates the view.
    /// - Parameters:
    ///   - viewModel: The Crypto hub view model.
    ///   - tagID: The Crypto tag's live Gamma id.
    public init(viewModel: CryptoHubViewModel, tagID: String?) {
        self._viewModel = State(initialValue: viewModel)
        self.tagID = tagID
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                timeframeChipRow
                header
                if isSearching {
                    searchField
                }
                subTabRow
                liveWindowCard
                content
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.vertical, DSLayout.spacing)
        }
        .background(DSColor.background)
        .eventDetailDestination()
        .navigationDestination(for: MarketNavigationTarget.self) {
            MarketDetailView(market: $0.market, eventID: $0.eventID)
        }
        .navigationDestination(for: CryptoUpDownNavigationTarget.self) { target in
            if let btcLiveFactory {
                // The pop must come from *inside* the pushed screen: this hub is the
                // stack's root, so its own `dismiss` is a no-op — reading it out here is
                // exactly what made "Next window →" do nothing.
                LiveWindowDestination { pop in
                    BTCLiveView(
                        viewModel: btcLiveFactory(target.liveContext) { side in
                            tradeContext = TradeSheetContext(market: target.market, side: side == .up ? .yes : .no)
                        },
                        // Pop back to the hub, whose pinned card follows the live window on
                        // the grid boundary — so returning lands on the current one. The
                        // refresh runs in the background rather than gating the pop: a slow
                        // request otherwise leaves the tap looking dead.
                        onNextWindow: {
                            Task { await viewModel.loadLiveWindow() }
                            pop()
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showsMoreSheet) { CryptoMoreSheetPlaceholder() }
        .sheet(item: $tradeContext) { context in
            TradeSheet(viewModel: TradeSheetViewModel(market: context.market, side: context.side, submitter: tradeSubmitter))
        }
        .task {
            if let tagID { await viewModel.loadIfNeeded(tagID: tagID) }
        }
        .task { await followLiveWindow() }
        .refreshable { await viewModel.refresh() }
    }

    /// Whether the row-2 search field is currently revealed.
    @State private var isSearching = false
    /// Whether the shared "More filters" placeholder sheet is presented (opened by the
    /// timeframe row's "•••More" chip).
    @State private var showsMoreSheet = false
    /// Whether the sort/period menu row is currently revealed, toggled by the header's
    /// filter icon. Starts hidden, matching the collapsed-by-default `AdvancedFilterRow`
    /// pattern used elsewhere in the app (`EventListViewModel.filterRowVisible`).
    @State private var showsSortPeriodRow = false
    /// Builds the BTC-live view model when a Crypto Up/Down card is tapped.
    @Environment(\.btcLiveFactory) private var btcLiveFactory
    /// The (simulated) trade submitter for the trade sheet opened from a live quick-bet.
    @Environment(\.tradeSubmitter) private var tradeSubmitter
    /// The context that presents the mock trade sheet, when a quick-bet is tapped on the
    /// live BTC screen. Same pattern as `EventDetailView.tradeContext`.
    @State private var tradeContext: TradeSheetContext?

    // MARK: - Timeframe chip row

    private var timeframeChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DSLayout.spacingSmall) {
                timeframeChip(.all, label: "All", glyph: "square.grid.2x2")
                timeframeChip(.fiveMin, label: "5 Min", glyph: "line.3.horizontal.decrease")
                timeframeChip(.fifteenMin, label: "15 Min", glyph: "circle.dashed")
                timeframeChip(.hourly, label: "1 Hour", glyph: "clock")
                Button { showsMoreSheet = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "ellipsis")
                        Text("More").font(DSFont.caption.bold())
                    }
                    .foregroundStyle(DSColor.textSecondary)
                    .padding(.horizontal, DSLayout.spacingMedium)
                    .padding(.vertical, DSLayout.spacingXSmall)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func timeframeChip(_ timeframe: CryptoHubViewModel.Timeframe, label: String, glyph: String) -> some View {
        let isSelected = viewModel.selectedTimeframe == timeframe
        return Button {
            viewModel.selectedTimeframe = timeframe
        } label: {
            HStack(spacing: 4) {
                Image(systemName: glyph)
                Text(label)
                Text("\(viewModel.timeframeCount(for: timeframe))")
                    .foregroundStyle(DSColor.textSecondary)
            }
            .font(DSFont.caption.bold())
            .foregroundStyle(isSelected ? .white : DSColor.textSecondary)
            .padding(.horizontal, DSLayout.spacingMedium)
            .padding(.vertical, DSLayout.spacingXSmall)
            .background(isSelected ? DSColor.accent : DSColor.surface)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header (title + search/filter icons + sort/period menus)

    private var header: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacing) {
            HStack {
                Text("Crypto").font(DSFont.title).foregroundStyle(DSColor.textPrimary)
                Spacer()
                Button {
                    isSearching.toggle()
                    if !isSearching { viewModel.searchQuery = "" }
                } label: {
                    Image(systemName: "magnifyingglass").foregroundStyle(DSColor.textPrimary)
                }
                .buttonStyle(.plain)
                Button { showsSortPeriodRow.toggle() } label: {
                    Image(systemName: "slider.horizontal.3").foregroundStyle(DSColor.textPrimary)
                }
                .buttonStyle(.plain)
            }
            if showsSortPeriodRow {
                HStack(spacing: DSLayout.spacingSmall) {
                    sortMenu
                    periodMenu
                    Spacer()
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(DSColor.textSecondary)
            TextField("Search", text: $viewModel.searchQuery)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textPrimary)
            if !viewModel.searchQuery.isEmpty {
                Button { viewModel.searchQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(DSColor.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(DSColor.surface).clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
    }

    private var sortMenu: some View {
        Menu {
            Button("24hr Volume") { viewModel.sortOption = .volume24hr }
            Button("Total Volume") { viewModel.sortOption = .totalVolume }
            Button("Liquidity") { viewModel.sortOption = .liquidity }
            Button("Newest") { viewModel.sortOption = .newest }
            Button("Ending Soon") { viewModel.sortOption = .endingSoon }
            Button("Competitive") { viewModel.sortOption = .competitive }
            Button("Earn 3.25%") {}.disabled(true)
        } label: {
            menuLabel(sortLabel)
        }
    }

    private var periodMenu: some View {
        Menu {
            Button("All") { viewModel.period = .all }
            Button("Daily") { viewModel.period = .daily }
            Button("Weekly") { viewModel.period = .weekly }
            Button("Monthly") { viewModel.period = .monthly }
        } label: {
            menuLabel(periodLabel)
        }
    }

    private func menuLabel(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(text).font(DSFont.caption.bold())
            Image(systemName: "chevron.down").font(.caption2)
        }
        .foregroundStyle(DSColor.textPrimary)
        .padding(.horizontal, DSLayout.spacingMedium)
        .padding(.vertical, DSLayout.spacingXSmall)
        .background(DSColor.surface)
        .clipShape(Capsule())
    }

    private var sortLabel: String {
        switch viewModel.sortOption {
        case .volume24hr: return "24hr Volume"
        case .totalVolume: return "Total Volume"
        case .liquidity: return "Liquidity"
        case .newest: return "Newest"
        case .endingSoon: return "Ending Soon"
        case .competitive: return "Competitive"
        }
    }

    private var periodLabel: String {
        switch viewModel.period {
        case .all: return "All"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }

    // MARK: - Sub-tabs

    private var subTabRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DSLayout.spacingLarge) {
                ForEach(CryptoHubViewModel.SubTab.allCases, id: \.self) { tab in
                    subTabButton(tab)
                }
            }
        }
    }

    private func subTabButton(_ tab: CryptoHubViewModel.SubTab) -> some View {
        let isSelected = viewModel.selectedSubTab == tab
        return Button {
            viewModel.selectedSubTab = tab
        } label: {
            Text(title(for: tab))
                .font(DSFont.subheadline.bold())
                .foregroundStyle(isSelected ? DSColor.accent : DSColor.textSecondary)
                .padding(.horizontal, isSelected ? DSLayout.spacingMedium : 0)
                .padding(.vertical, DSLayout.spacingXSmall)
                .background(isSelected ? DSColor.accentTint : Color.clear)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func title(for tab: CryptoHubViewModel.SubTab) -> String {
        switch tab {
        case .all: return "All"
        case .upDown: return "Up / Down"
        case .aboveBelow: return "Above / Below"
        case .priceRange: return "Price Range"
        case .hitPrice: return "Hit Price"
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            StateView(.loading).frame(height: 320)
        case .failed(let message):
            StateView(.error(message)).frame(height: 320)
        case .loaded:
            if viewModel.visibleEvents.isEmpty {
                StateView(.empty).frame(height: 320)
            } else {
                LazyVStack(spacing: DSLayout.spacing) {
                    ForEach(viewModel.visibleEvents, id: \.event.id) { item in
                        card(for: item.event, kind: item.kind)
                    }
                }
            }
        }
    }

    /// Keeps the pinned card on the current window for as long as the hub is on screen.
    ///
    /// Sleeps to the *window boundary* rather than on a fixed interval: a repeating 5-minute
    /// timer started mid-window would settle permanently out of phase and keep showing a
    /// resolved window as live. The small grace period covers clock skew and the moment
    /// Gamma needs to publish the next slot. Cancelled automatically when the view goes away.
    private func followLiveWindow() async {
        /// Seconds past the boundary before asking for the next window.
        let grace: TimeInterval = 2
        while !Task.isCancelled {
            let wait = viewModel.nextLiveWindowBoundary.timeIntervalSinceNow + grace
            do {
                try await Task.sleep(nanoseconds: UInt64(max(wait, 1) * 1_000_000_000))
            } catch {
                return  // cancelled
            }
            await viewModel.loadLiveWindow()
        }
    }

    /// The pinned BTC Up/Down 5m card, matching the card `polymarket.com/crypto` leads with.
    ///
    /// Rendered outside `content` so it survives the list's loading/empty states — the
    /// window is resolved by a separate request and shouldn't blink out while the tag list
    /// reloads.
    @ViewBuilder
    private var liveWindowCard: some View {
        if viewModel.showsLiveWindow, let event = viewModel.liveWindow {
            CryptoUpDownCard(event: event)
        }
    }

    @ViewBuilder
    private func card(for event: Event, kind: CryptoMarketKind) -> some View {
        if kind == .upDown {
            CryptoUpDownCard(event: event)
        } else {
            CryptoStrikeCard(event: event, kind: kind)
        }
    }
}

/// Hosts a pushed live-window screen and hands it a working "pop back" closure.
///
/// `dismiss` has to be read from a view that is *itself* the pushed destination —
/// `CryptoHubView` is the stack's root, so its `dismiss` silently does nothing. This
/// wrapper exists purely to give the destination its own environment to read.
private struct LiveWindowDestination<Content: View>: View {
    /// Pops this pushed screen off the navigation stack.
    @Environment(\.dismiss) private var dismiss
    /// Builds the pushed screen, given a closure that pops back to the hub.
    let content: (_ pop: @escaping () -> Void) -> Content

    var body: some View {
        content { dismiss() }
    }
}

/// Placeholder for the deferred "More filters" sheet (the 10 additional timeframe buckets
/// and the per-coin list). Opened by both the timeframe row's "•••More" chip and the
/// header's filter icon. Real content is a separate, later slice.
private struct CryptoMoreSheetPlaceholder: View {
    var body: some View {
        VStack(spacing: DSLayout.spacing) {
            Image(systemName: "slider.horizontal.3")
                .font(.largeTitle)
                .foregroundStyle(DSColor.textSecondary)
            Text("More filters coming soon")
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.background)
    }
}
