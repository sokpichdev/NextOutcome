import SwiftUI
import MarketsDomain
import DesignSystem

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
                header
                subTabRow
                content
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.vertical, DSLayout.spacing)
        }
        .background(DSColor.background)
        .navigationDestination(for: Event.self) { EventDetailView(event: $0) }
        .navigationDestination(for: MarketNavigationTarget.self) {
            MarketDetailView(market: $0.market, eventID: $0.eventID)
        }
        .task {
            if let tagID { await viewModel.loadIfNeeded(tagID: tagID) }
        }
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Header (title + sort/period menus)

    private var header: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacing) {
            Text("Crypto").font(DSFont.title).foregroundStyle(DSColor.textPrimary)
            HStack(spacing: DSLayout.spacingSmall) {
                sortMenu
                periodMenu
                Spacer()
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Button("Volume") { viewModel.sortOption = .volume }
            Button("Ending Soon") { viewModel.sortOption = .endingSoon }
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
        case .volume: return "Volume"
        case .endingSoon: return "Ending Soon"
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

    @ViewBuilder
    private func card(for event: Event, kind: CryptoMarketKind) -> some View {
        if kind == .upDown {
            LiveUpDownCard(event: event)
        } else {
            CryptoStrikeCard(event: event, kind: kind)
        }
    }
}
