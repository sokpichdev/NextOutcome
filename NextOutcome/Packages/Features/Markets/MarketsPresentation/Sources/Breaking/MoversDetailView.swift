//
//  MoversDetailView.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import SwiftUI
import MarketsDomain
import DesignSystem
import SharedDomain

/// The bespoke Breaking movers detail — step 2 of the Breaking flow: a listing of every
/// candidate/deadline in the mover's parent event (the event's total volume, then one row
/// per candidate with its own chance and Buy Yes/No), matching the web. Buy Yes/No opens the
/// trade sheet directly; tapping a row instead pushes that specific market's own detail
/// (step 3), which carries the same Rules/Comments/Top Holders/Positions/Activity treatment.
public struct MoversDetailView: View {
    /// The view model, which fetches the parent event and social strip.
    @State private var viewModel: MoversDetailViewModel
    /// The (simulated) trade submitter for the Buy Yes/No sheet.
    @Environment(\.tradeSubmitter) private var tradeSubmitter
    /// The context that presents the mock trade sheet, when a Buy button is tapped.
    @State private var tradeContext: TradeSheetContext?
    /// Whether the Rules bottom sheet is presented.
    @State private var showsRulesSheet = false
    /// Whether the Comments/Top Holders/Positions/Activity bottom sheet is presented.
    @State private var showsDiscussSheet = false

    /// Creates the view.
    /// - Parameter viewModel: The movers-detail view model (built by the factory).
    public init(viewModel: MoversDetailViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    /// The per-market resolution rules to feed the `RulesExpander` (markets without rules are
    /// skipped), mirroring `EventDetailView`'s equivalent.
    private var marketRules: [RulesExpander.MarketRule] {
        (viewModel.event?.markets ?? []).compactMap { market in
            guard let rules = market.rules, !rules.isEmpty else { return nil }
            return RulesExpander.MarketRule(id: market.id, title: market.groupItemTitle ?? market.question, text: rules)
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSLayout.spacingLarge) {
                header
                listingSection
            }
            .padding(.horizontal, DSLayout.margin)
            .padding(.top, DSLayout.spacing)
        }
        .background(DSColor.background)
        .detailToolbar(
            title: viewModel.mover.eventTitle, iconURL: viewModel.mover.imageURL,
            actions: [.rules, .discuss, .bookmark, .link], onAction: handleHeaderAction
        )
        .navigationDestination(for: MarketNavigationTarget.self) {
            MarketDetailView(market: $0.market, eventID: $0.eventID)
        }
        .sheet(item: $tradeContext) { context in
            TradeSheet(viewModel: TradeSheetViewModel(market: context.market, side: context.side, submitter: tradeSubmitter))
        }
        .sheet(isPresented: $showsRulesSheet) {
            ScrollView {
                RulesExpander(eventDescription: viewModel.event?.description, marketRules: marketRules, startsExpanded: true)
                    .padding(DSLayout.margin)
            }
            .presentationDetents([.medium, .large])
            .background(DSColor.background)
        }
        .sheet(isPresented: $showsDiscussSheet) {
            ScrollView {
                if let socialStrip = viewModel.socialStrip {
                    SocialStripView(viewModel: socialStrip)
                        .padding(DSLayout.margin)
                }
            }
            .presentationDetents([.medium, .large])
            .background(DSColor.background)
        }
        .task { await viewModel.load() }
    }

    /// Routes a toolbar trailing-action tap: Rules/Comments open their bottom sheets.
    private func handleHeaderAction(_ action: DetailToolbarActions) {
        if action.contains(.rules) { showsRulesSheet = true }
        if action.contains(.discuss) { showsDiscussSheet = true }
    }

    /// Category breadcrumb + the parent event's title (matching the web, which always shows
    /// the event's own title here — e.g. "GPT-5.6 released by…?" — never the specific tapped
    /// market's full question).
    private var header: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingXSmall) {
            if !viewModel.categoryBreadcrumb.isEmpty {
                Text(viewModel.categoryBreadcrumb)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
            Text(viewModel.event?.title ?? viewModel.mover.eventTitle)
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The listing body: the event's total volume, then one row per candidate/deadline, or a
    /// loading/error placeholder while the event loads.
    @ViewBuilder
    private var listingSection: some View {
        if let eventID = viewModel.event?.id {
            VStack(alignment: .leading, spacing: 0) {
                Text(volumeText)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .padding(.bottom, DSLayout.spacingSmall)
                ForEach(Array(viewModel.listingMarkets.enumerated()), id: \.element.id) { index, market in
                    MoverCandidateRow(market: market, eventID: eventID) { side in
                        tradeContext = TradeSheetContext(market: market, side: side)
                    }
                    if index < viewModel.listingMarkets.count - 1 {
                        Divider().overlay(DSColor.separator)
                    }
                }
            }
        } else if let message = viewModel.errorMessage {
            VStack(spacing: DSLayout.spacingSmall) {
                Text(message).font(DSFont.subheadline).foregroundStyle(DSColor.textSecondary)
                Button("Retry") { Task { await viewModel.load() } }.tint(DSColor.accent)
            }
            .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            StateView(.loading).frame(height: 220)
        }
    }

    /// "$358K Vol." line built from the parent event's total volume.
    private var volumeText: String {
        let volume = viewModel.event?.volume ?? viewModel.mover.volume24h
        return "\(MarketFormatting.compactUSD(volume)) Vol."
    }
}
