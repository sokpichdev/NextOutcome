//
//  SportsHubView.swift
//  NextOutcome
//
//  Created by Sok Pich on 06/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// The Sports hub screen shown when the category rail selects Sports: a Live/Futures mode
/// bar plus league chips (World Cup, Wimbledon, MLB, UFC, …). Tapping World Cup pushes the
/// existing `WorldCupHubView`; every other league chip pushes a generic league detail
/// screen. Live shows the general sports feed grouped by league; Futures shows a sport
/// picker (NBA/EPL) over ranked futures markets.
public struct SportsHubView: View {
    /// The view model driving the hub's data and Live/Futures mode.
    @State private var viewModel: SportsHubViewModel
    /// The shared World Cup hub view model, reused so its data survives navigation
    /// (the same instance shown when the rail selects World Cup directly).
    private let worldCupViewModel: WorldCupHubViewModel
    /// The use case used to build a league detail screen's view model on demand.
    private let fetchAllEvents: FetchAllEventsUseCase
    /// Whether the Live tab's league search field is shown.
    @State private var isSearchActive = false
    /// The Live tab's league search text.
    @State private var searchQuery = ""
    /// The league chip selected in the mode bar, if any. Non-nil replaces the Live/Futures
    /// content with that league's detail, in place — no navigation push.
    @State private var selectedLeague: SportsLeague?
    /// The team logo tapped in the Live tab, if any — drives the profile push.
    @State private var selectedTeam: TeamProfileTarget?
    /// Builds the profile view model when a team logo is tapped.
    @Environment(\.teamProfileFactory) private var teamProfileFactory

    /// Creates the view.
    /// - Parameters:
    ///   - viewModel: The Sports hub view model.
    ///   - worldCupViewModel: The shared World Cup hub view model.
    ///   - fetchAllEvents: The use case for building league detail screens.
    public init(viewModel: SportsHubViewModel, worldCupViewModel: WorldCupHubViewModel, fetchAllEvents: FetchAllEventsUseCase) {
        self._viewModel = State(initialValue: viewModel)
        self.worldCupViewModel = worldCupViewModel
        self.fetchAllEvents = fetchAllEvents
    }

    public var body: some View {
        VStack(spacing: 0) {
            SportsModeBar(mode: $viewModel.mode, leagues: viewModel.leagues, selectedLeague: $selectedLeague)
                .padding(.vertical, DSLayout.spacingSmall)
            if selectedLeague == nil { header }
            if isSearchActive, selectedLeague == nil, viewModel.mode == .live { searchField }
            content
        }
        .background(DSColor.background)
        .environment(\.oddsFormat, viewModel.oddsFormat)
        .environment(\.showSpreadsAndTotals, viewModel.showSpreadsAndTotals)
        .task { await viewModel.loadIfNeeded() }
    }

    /// The Odds Format menu icon: Odds Format plus Show Spreads + Totals (no sort — Volume/
    /// Soonest sort was removed from this menu). Lives in `header`, alongside the "Sports
    /// Live"/"Sports Futures" title and search icon, so it's only reachable when no league
    /// chip is selected (the embedded league/World Cup content isn't affected by it).
    private var oddsFormatMenu: some View {
        Menu {
            Section("Odds Format") {
                ForEach(OddsFormat.allCases, id: \.self) { format in
                    Button {
                        viewModel.oddsFormat = format
                    } label: {
                        if format == viewModel.oddsFormat { Label(format.title, systemImage: "checkmark") }
                        else { Text(format.title) }
                    }
                }
            }
            Button {
                viewModel.showSpreadsAndTotals.toggle()
            } label: {
                if viewModel.showSpreadsAndTotals { Label("Show Spreads + Totals", systemImage: "checkmark") }
                else { Text("Show Spreads + Totals") }
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .foregroundStyle(DSColor.textPrimary)
        }
        .accessibilityLabel("Odds Format")
    }

    /// Title + search toggle + Odds Format menu, all on one row.
    private var header: some View {
        HStack(spacing: DSLayout.spacing) {
            Text(viewModel.mode == .live ? "Sports Live" : "Sports Futures")
                .font(DSFont.largeTitle)
                .foregroundStyle(DSColor.textPrimary)
            Spacer()
            if viewModel.mode == .live {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isSearchActive.toggle() }
                    if !isSearchActive { searchQuery = "" }
                } label: {
                    Image(systemName: isSearchActive ? "xmark.circle.fill" : "magnifyingglass")
                        .foregroundStyle(DSColor.textPrimary)
                }
            }
            oddsFormatMenu
        }
        .padding(.horizontal, DSLayout.margin)
        .padding(.top, DSLayout.spacing)
    }

    /// The Live tab's league search field.
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(DSColor.textSecondary)
            TextField("Search sports", text: $searchQuery)
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.textPrimary)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(DSColor.surface).clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
        .padding(.horizontal, DSLayout.margin)
        .padding(.top, DSLayout.spacingSmall)
    }

    /// The selected league's detail (if a league chip is active), else the selected mode's
    /// content, or a loading/error placeholder.
    ///
    /// `WorldCupHubView` and `SportsLeagueDetailView` each declare their own
    /// `navigationDestination(for:)` for `Event`/`MarketNavigationTarget` (needed since
    /// `WorldCupHubView` is also reachable standalone, outside this hub). Declaring the same
    /// destinations again here — around the *entire* `content`, embedded children included —
    /// would register two handlers for the same type in one `NavigationStack` at once, which
    /// SwiftUI doesn't support (surfaces as a broken/reparented view hierarchy at runtime).
    /// So these destinations are scoped to `ownModeContent` only; the embedded branches rely
    /// entirely on their own.
    @ViewBuilder
    private var content: some View {
        if let selectedLeague {
            if selectedLeague.title == "World Cup" {
                WorldCupHubView(viewModel: worldCupViewModel)
            } else {
                SportsLeagueDetailView(league: selectedLeague, fetchAllEvents: fetchAllEvents)
                    .id(selectedLeague.id)
            }
        } else {
            ownModeContent
                .navigationDestination(for: Event.self) { EventDetailView(event: $0) }
                .navigationDestination(for: MarketNavigationTarget.self) {
                    MarketDetailView(market: $0.market, eventID: $0.eventID)
                }
                .navigationDestination(item: $selectedTeam) { target in
                    if let teamProfileFactory {
                        TeamProfileView(viewModel: teamProfileFactory(target))
                    }
                }
        }
    }

    /// The selected mode's content (Live/Futures), or a loading/error placeholder.
    @ViewBuilder
    private var ownModeContent: some View {
        switch viewModel.state {
        case .idle, .loading:
            StateView(.loading).frame(maxHeight: .infinity)
        case .failed(let message):
            StateView(.error(message)).frame(maxHeight: .infinity)
        case .loaded:
            switch viewModel.mode {
            case .live:    liveContent
            case .futures: futuresContent
            }
        }
    }

    /// The Live tab: league sections of match cards, filtered by `searchQuery`.
    private var liveContent: some View {
        let groups = viewModel.liveGroups.compactMap { group -> (league: SportsLeague, events: [Event])? in
            guard !searchQuery.isEmpty else { return group }
            let filtered = group.events.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }
            return filtered.isEmpty ? nil : (group.league, filtered)
        }
        return ScrollView {
            if groups.isEmpty {
                StateView(.empty).padding(.top, DSLayout.spacingXLarge)
            } else {
                LazyVStack(alignment: .leading, spacing: DSLayout.spacingLarge) {
                    ForEach(groups, id: \.league.id) { group in
                        VStack(alignment: .leading, spacing: DSLayout.spacing) {
                            Text(group.league.title.uppercased())
                                .font(DSFont.caption.bold())
                                .foregroundStyle(DSColor.textSecondary)
                            ForEach(group.events) { event in
                                NavigationLink(value: event) {
                                    HomeCard(
                                        event: event,
                                        onTeamTap: { selectedTeam = $0 },
                                        leagueSlug: group.league.title.lowercased()
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, DSLayout.margin)
                .padding(.vertical, DSLayout.spacing)
            }
        }
        .refreshable { await viewModel.refresh() }
    }

    /// The Futures tab: a sport picker (NBA/EPL) over ranked futures markets.
    private var futuresContent: some View {
        ScrollView {
            VStack(spacing: DSLayout.spacing) {
                if !viewModel.futuresSports.isEmpty {
                    FilterChipRow<String?>(
                        items: viewModel.futuresSports.map { .init(id: $0.id, label: $0.title) },
                        selectedID: viewModel.selectedFuturesSportID,
                        onSelect: { id in if let id { Task { await viewModel.selectFuturesSport(id) } } }
                    )
                    .padding(.horizontal, -DSLayout.margin)
                }
                if viewModel.futuresEvents.isEmpty {
                    StateView(.empty).padding(.top, DSLayout.spacingXLarge)
                } else {
                    LazyVStack(spacing: DSLayout.spacing) {
                        ForEach(viewModel.futuresEvents) { event in
                            FuturesOddsCard(event: event)
                        }
                    }
                }
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.vertical, DSLayout.spacing)
        }
        .refreshable { await viewModel.refresh() }
    }
}
