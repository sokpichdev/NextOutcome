//
//  PoliticsHubView.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem

/// The Politics hub (2026 Midterms): a countdown hero, the two headline Senate/House control
/// cards, and a searchable, chamber-tabbed list of every race. Tapping a race pushes the
/// existing `EventDetailView` (full Rules/chart/comments treatment, same as any other event).
public struct PoliticsHubView: View {
    /// The view model driving the hub.
    @State private var viewModel: PoliticsHubViewModel
    /// The (simulated) trade submitter for the headline cards' Trade buttons.
    @Environment(\.tradeSubmitter) private var tradeSubmitter
    /// The context that presents the mock trade sheet, when a Trade button is tapped.
    @State private var tradeContext: TradeSheetContext?
    /// The currently-shown card in the Referendums carousel.
    @State private var referendumIndex = 0
    /// The currently-shown card in the Biggest-races carousel.
    @State private var biggestRaceIndex = 0

    /// Creates the view.
    /// - Parameter viewModel: The Politics hub view model.
    public init(viewModel: PoliticsHubViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DSLayout.spacingLarge) {
                heroSection
                content
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.vertical, DSLayout.spacing)
        }
        .background(DSColor.background)
        .navigationDestination(for: Event.self) { EventDetailView(event: $0) }
        .sheet(item: $tradeContext) { context in
            TradeSheet(viewModel: TradeSheetViewModel(market: context.market, side: context.side, submitter: tradeSubmitter))
        }
        .task { await viewModel.loadIfNeeded() }
        .refreshable { await viewModel.refresh() }
    }

    /// Loading/empty/error state, or the loaded hub content.
    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            StateView(.loading).frame(height: 320)
        case .failed(let message):
            StateView(.error(message)).frame(height: 320)
        case .loaded:
            controlCards
            searchBar
            chamberTabs
            mapSection
            racesList
            referendumsSection
            biggestRacesSection
            oddsBreakdownSection
            aboutSection
            faqSection
        }
    }

    // MARK: - Map

    /// The state-shaped lean map for the selected chamber. House races are single districts,
    /// not whole states, so the map is only meaningful for Senate/Governor.
    @ViewBuilder
    private var mapSection: some View {
        if viewModel.selectedChamber != .house {
            VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
                USStateMapView(colors: viewModel.leanByState(for: viewModel.selectedChamber).mapValues(\.color))
                    .frame(maxWidth: .infinity)
                mapLegend
            }
        }
    }

    private var mapLegend: some View {
        let leans: [RaceLean] = [.safeD, .likelyD, .leanD, .tossUp, .leanR, .likelyR, .safeR]
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DSLayout.spacing) {
                ForEach(leans, id: \.self) { lean in
                    HStack(spacing: 4) {
                        Circle().fill(lean.color).frame(width: 8, height: 8)
                        Text(lean.title).font(DSFont.caption2).foregroundStyle(DSColor.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Odds breakdown

    /// "Midterms 2026 odds": per-race candidate odds for the selected chamber's top races.
    @ViewBuilder
    private var oddsBreakdownSection: some View {
        if !viewModel.filteredRaces.isEmpty {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                Text("Midterms 2026 odds")
                    .font(DSFont.title)
                    .foregroundStyle(DSColor.textPrimary)
                ForEach(viewModel.filteredRaces.prefix(5)) { race in
                    RaceOddsCard(event: race)
                }
            }
        }
    }

    // MARK: - About + FAQ

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
            Text("About the 2026 U.S. Midterm Elections")
                .font(DSFont.title)
                .foregroundStyle(DSColor.textPrimary)
            Text("""
            The 2026 U.S. midterm elections, held on November 3, 2026, will determine control \
            of both chambers of Congress and dozens of governorships. Every House seat, roughly \
            a third of the Senate, and many state governorships are up for election. These \
            markets track the probability of each outcome based on real trading activity.
            """)
            .font(DSFont.subheadline)
            .foregroundStyle(DSColor.textSecondary)
        }
    }

    private static let faqs: [(String, String)] = [
        ("How are these odds calculated?", "Each market's price reflects the probability traders assign to that outcome, based on real money bought and sold on that side."),
        ("When do these markets resolve?", "Race markets resolve once a winner is officially called by major news outlets, typically on election night or shortly after."),
        ("Can the odds change?", "Yes — prices move continuously as new information (polls, news, ads) shifts trader sentiment."),
    ]

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacing) {
            Text("FAQ").font(DSFont.title).foregroundStyle(DSColor.textPrimary)
            ForEach(Self.faqs, id: \.0) { question, answer in
                FAQRow(question: question, answer: answer)
            }
        }
    }

    // MARK: - Carousels

    /// "Referendums — top issue markets": a swipeable carousel of ballot-measure cards.
    @ViewBuilder
    private var referendumsSection: some View {
        if !viewModel.referendums.isEmpty {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                sectionHeading("Referendums", subtitle: "top issue markets")
                CardCarousel(count: viewModel.referendums.count, index: $referendumIndex) { index in
                    MiniMarketCard(event: viewModel.referendums[index]) { market, side in
                        tradeContext = TradeSheetContext(market: market, side: side)
                    }
                }
            }
        }
    }

    /// "Biggest races — most pivotal markets": a swipeable carousel of the highest-volume races.
    @ViewBuilder
    private var biggestRacesSection: some View {
        if !viewModel.biggestRaces.isEmpty {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                sectionHeading("Biggest races", subtitle: "most pivotal markets")
                CardCarousel(count: viewModel.biggestRaces.count, index: $biggestRaceIndex) { index in
                    MiniMarketCard(event: viewModel.biggestRaces[index]) { market, side in
                        tradeContext = TradeSheetContext(market: market, side: side)
                    }
                }
            }
        }
    }

    /// A two-line section heading: a bold title and a muted subtitle beneath it.
    private func sectionHeading(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(DSFont.title).foregroundStyle(DSColor.textPrimary)
            Text(subtitle).font(DSFont.title).foregroundStyle(DSColor.textSecondary)
        }
    }

    // MARK: - Hero

    /// "Updated {date}" + title + a live countdown to election day.
    private var heroSection: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
            Text("Updated \(Self.updatedFormatter.string(from: Date()))")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
            Text("2026 Midterm Election Odds & Predictions")
                .font(DSFont.title)
                .foregroundStyle(DSColor.textPrimary)
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                CountdownRow(remaining: PoliticsHubViewModel.electionDate.timeIntervalSince(timeline.date))
            }
        }
    }

    private static let updatedFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy h:mm a 'ET'"
        f.timeZone = TimeZone(identifier: "America/New_York")
        return f
    }()

    // MARK: - Control cards

    /// The two headline "{X}% chance {Party} win the {Chamber}" cards.
    @ViewBuilder
    private var controlCards: some View {
        if let summary = PartyControlSummary.summary(for: viewModel.senateControlEvent) {
            ControlCard(chamberTitle: "Senate", summary: summary, composition: .senate) { side in
                tradeContext = TradeSheetContext(market: summary.market, side: side)
            }
        }
        if let summary = PartyControlSummary.summary(for: viewModel.houseControlEvent) {
            ControlCard(chamberTitle: "House", summary: summary, composition: .house) { side in
                tradeContext = TradeSheetContext(market: summary.market, side: side)
            }
        }
    }

    // MARK: - Search + chamber tabs

    private var searchBar: some View {
        HStack(spacing: DSLayout.spacingSmall) {
            Image(systemName: "magnifyingglass").foregroundStyle(DSColor.textSecondary)
            TextField("Find a race", text: $viewModel.searchQuery)
                .foregroundStyle(DSColor.textPrimary)
        }
        .padding(DSLayout.spacingMedium)
        .background(DSColor.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
    }

    private var chamberTabs: some View {
        HStack(spacing: DSLayout.spacingLarge) {
            ForEach([Chamber.senate, .house, .governor], id: \.self) { chamber in
                Button {
                    viewModel.selectedChamber = chamber
                } label: {
                    VStack(spacing: DSLayout.spacingXSmall) {
                        Text("\(chamber.title) \(viewModel.raceCount(for: chamber))")
                            .font(DSFont.subheadline.bold())
                            .foregroundStyle(viewModel.selectedChamber == chamber ? DSColor.textPrimary : DSColor.textSecondary)
                        Rectangle()
                            .fill(viewModel.selectedChamber == chamber ? DSColor.textPrimary : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Races list

    private var racesList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(viewModel.filteredRaces.enumerated()), id: \.element.id) { index, race in
                NavigationLink(value: race) {
                    RaceRow(event: race)
                }
                .buttonStyle(.plain)
                if index < viewModel.filteredRaces.count - 1 {
                    Divider().overlay(DSColor.separator)
                }
            }
            if viewModel.filteredRaces.isEmpty {
                Text("No races found.")
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
                    .padding(.vertical, DSLayout.spacingLarge)
            }
        }
    }
}

/// A live "Days / Hours / Minutes / Seconds" countdown row.
private struct CountdownRow: View {
    /// Seconds remaining until election day (may be negative once it's passed).
    let remaining: TimeInterval

    var body: some View {
        HStack(spacing: DSLayout.spacingLarge) {
            unit(Int(remaining / 86400), "DAYS")
            unit(Int(remaining.truncatingRemainder(dividingBy: 86400) / 3600), "HOURS")
            unit(Int(remaining.truncatingRemainder(dividingBy: 3600) / 60), "MINUTES")
            unit(Int(remaining.truncatingRemainder(dividingBy: 60)), "SECONDS")
        }
    }

    private func unit(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(max(value, 0))")
                .font(DSFont.largeTitle)
                .foregroundStyle(DSColor.textSecondary)
            Text(label)
                .font(DSFont.caption2)
                .foregroundStyle(DSColor.textSecondary)
        }
    }
}

/// One headline party-control card: "{X}% chance {Party} win the {Chamber}" + Trade button.
private struct ControlCard: View {
    let chamberTitle: String
    let summary: PartyControlSummary
    let composition: ChamberComposition
    let onTrade: (Side) -> Void

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
                Text("\(MarketFormatting.percent(summary.percent)) chance \(summary.leadingParty) win the \(chamberTitle)")
                    .font(DSFont.headline)
                    .foregroundStyle(summary.leadingParty == "Democrats" ? DSColor.accent : DSColor.negative)
                Button {
                    onTrade(.yes)
                } label: {
                    Text("Trade")
                        .font(DSFont.subheadline.bold())
                        .foregroundStyle(DSColor.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DSLayout.spacingSmall)
                        .background(DSColor.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
                }
                .buttonStyle(.plain)
                SeatPictogram(composition: composition)
            }
        }
    }
}

/// One race's candidate odds breakdown, sorted highest chance first.
private struct RaceOddsCard: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingXSmall) {
            Text(event.title.trimmingCharacters(in: .whitespaces))
                .font(DSFont.subheadline.bold())
                .foregroundStyle(DSColor.textPrimary)
            ForEach(event.markets.sorted { ($0.yesOutcome?.price ?? 0) > ($1.yesOutcome?.price ?? 0) }.prefix(6)) { market in
                HStack {
                    Text(market.groupItemTitle ?? market.question)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Text(MarketFormatting.percent(market.yesOutcome?.price ?? 0))
                        .font(DSFont.caption.bold())
                        .foregroundStyle(DSColor.textPrimary)
                }
                Divider().overlay(DSColor.separator)
            }
        }
        .padding(.vertical, DSLayout.spacingSmall)
    }
}

/// One expandable FAQ row.
private struct FAQRow: View {
    let question: String
    let answer: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(question)
                        .font(DSFont.subheadline.bold())
                        .foregroundStyle(DSColor.textPrimary)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
            .buttonStyle(.plain)
            if isExpanded {
                Text(answer)
                    .font(DSFont.subheadline)
                    .foregroundStyle(DSColor.textSecondary)
            }
            Divider().overlay(DSColor.separator)
        }
    }
}

/// One row in the all-races list: title, state, and current chance.
private struct RaceRow: View {
    let event: Event

    var body: some View {
        let classification = ChamberClassifier.classify(title: event.title)
        let lean = RaceLeanClassifier.lean(forRaceMarkets: event.markets)
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title.trimmingCharacters(in: .whitespaces))
                    .font(DSFont.subheadline.bold())
                    .foregroundStyle(DSColor.textPrimary)
                if let code = classification.stateCode, let name = USStateGeometry.stateNames[code] {
                    Text(name)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
            Spacer()
            if lean != .noRace {
                Text(lean.title)
                    .font(DSFont.caption.bold())
                    .foregroundStyle(lean.color)
            }
        }
        .padding(.vertical, DSLayout.spacingSmall)
    }
}
